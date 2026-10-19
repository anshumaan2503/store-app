import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  StoreNotification,
  StoreNotificationDocument,
} from './schemas/store-notification.schema';
import { StoreNewItem } from '../new-store/store-items/store-item/entities/store-item.schema';
import {
  IndentRaise,
  IndentRaiseDocument,
} from '../stock-refill-request/schemas/stock-refill-request.schema';

@Injectable()
export class StoreNotificationService {
  constructor(
    @InjectModel(StoreNotification.name, 'store')
    private readonly notificationModel: Model<StoreNotificationDocument>,
    @InjectModel(StoreNewItem.name, 'store')
    private readonly itemModel: Model<StoreNewItem>,
    @InjectModel(IndentRaise.name, 'store')
    private readonly refillModel: Model<IndentRaiseDocument>,
  ) {}

  /**
   * Evaluates current inventory for low-stock items (YELLOW rule: available > 0 && available <= threshold).
   * Ensures exactly ONE notification record per user + item + active low-stock state.
   * Red (avail <= 0) and Normal stock NEVER generate low-stock notifications.
   * Items that leave yellow state (restocked or became 0) are deactivated.
   */
  async syncLowStockNotifications(userId: string): Promise<void> {
    if (!userId) return;

    // Fetch active store items (non-scrap)
    const items = await this.itemModel
      .find({ isScrap: { $ne: true } })
      .lean()
      .exec();

    const yellowItems: any[] = [];

    for (const item of items) {
      const avail =
        typeof item.stockAvailableQuantity === 'number'
          ? item.stockAvailableQuantity
          : 0;
      const total =
        typeof item.totalStockQuantity === 'number'
          ? item.totalStockQuantity
          : 0;

      // Authoritative low-stock threshold formula:
      // If item.minStockQuantity > 0, use item.minStockQuantity as threshold.
      // Otherwise fall back to (totalStock * 0.1) < 1 ? 1 : (totalStock * 0.1)
      const minConfig =
        typeof item.minStockQuantity === 'number' && item.minStockQuantity > 0
          ? item.minStockQuantity
          : 0;
      const threshold =
        minConfig > 0 ? minConfig : total * 0.1 < 1 ? 1 : total * 0.1;

      // STRICT BUSINESS RULE:
      // YELLOW: avail > 0 && avail <= threshold
      // RED: avail <= 0 (DO NOT NOTIFY)
      // NORMAL: avail > threshold (DO NOT NOTIFY)
      if (avail > 0 && avail <= threshold) {
        yellowItems.push(item);
      }
    }

    const yellowItemIds: Types.ObjectId[] = [];

    for (const item of yellowItems) {
      yellowItemIds.push(item._id);

      const avail = item.stockAvailableQuantity ?? 0;
      const total = item.totalStockQuantity ?? 0;
      const itemName = item.itemName || 'Item';
      const itemCode = item.itemCode || '';
      const unit = item.unit || '';

      // Check if this notification was already dismissed by the user
      const existing = await this.notificationModel.findOne({
        userId,
        itemId: item._id,
        type: 'LOW_STOCK',
      });

      if (existing && existing.isDismissed) {
        // User explicitly removed/dismissed this notification; do not re-activate
        continue;
      }

      // Upsert: exactly ONE notification for (userId, itemId, 'LOW_STOCK')
      await this.notificationModel.findOneAndUpdate(
        {
          userId,
          itemId: item._id,
          type: 'LOW_STOCK',
        },
        {
          $set: {
            itemName,
            itemCode,
            unit,
            availableQuantity: avail,
            totalQuantity: total,
            title: 'Stock running low',
            message: `${itemName} is running low. Only ${avail} available.`,
            isActive: true,
            isDismissed: false,
          },
          $setOnInsert: {
            isRead: false,
            createdAt: new Date(),
          },
        },
        { upsert: true, new: true },
      );
    }

    // Deactivate notifications for items that are no longer in yellow state
    // (e.g. stock recovered to normal, or stock dropped to 0/red, or item deleted)
    await this.notificationModel.updateMany(
      {
        userId,
        type: 'LOW_STOCK',
        isActive: true,
        itemId: { $nin: yellowItemIds },
      },
      {
        $set: { isActive: false, isDismissed: false },
      },
    );
  }

  async getNotifications(userId: string) {
    await this.syncLowStockNotifications(userId);

    const userFilter: any = { isActive: true, isDismissed: { $ne: true } };
    if (userId) {
      userFilter.$or = [{ userId }, { userId: '' }, { userId: { $exists: false } }];
    }

    const notifications = await this.notificationModel
      .find(userFilter)
      .sort({ createdAt: -1 })
      .lean()
      .exec();

    if (notifications.length === 0) {
      return [];
    }

    // Identify which items currently have a PENDING refill request
    const itemIds = notifications.map((n) => n.itemId);
    const pendingRequests = await this.refillModel
      .find({
        itemId: { $in: itemIds },
        status: 'PENDING',
      })
      .select('itemId requestNo')
      .lean()
      .exec();

    const pendingItemIds = new Set(
      pendingRequests.map((r) => r.itemId.toString()),
    );

    return notifications.map((n) => ({
      ...n,
      id: n._id.toString(),
      hasPendingRefill: pendingItemIds.has(n.itemId.toString()),
    }));
  }

  async getUnreadCount(userId: string) {
    await this.syncLowStockNotifications(userId);

    const userFilter: any = {
      isActive: true,
      isDismissed: { $ne: true },
      isRead: false,
    };
    if (userId) {
      userFilter.$or = [{ userId }, { userId: '' }, { userId: { $exists: false } }];
    }

    const count = await this.notificationModel.countDocuments(userFilter);

    return { count };
  }

  async markAsRead(id: string, userId: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid notification ID');
    }

    const query: any = { _id: id };
    if (userId) {
      query.$or = [{ userId }, { userId: '' }, { userId: { $exists: false } }];
    }

    const updated = await this.notificationModel.findOneAndUpdate(
      query,
      { $set: { isRead: true, readAt: new Date() } },
      { new: true },
    );

    if (!updated) {
      throw new NotFoundException('Notification not found');
    }

    return updated;
  }

  async markAllAsRead(userId: string) {
    const query: any = {
      isActive: true,
      isDismissed: { $ne: true },
      isRead: false,
    };
    if (userId) {
      query.$or = [{ userId }, { userId: '' }, { userId: { $exists: false } }];
    }

    await this.notificationModel.updateMany(
      query,
      { $set: { isRead: true, readAt: new Date() } },
    );

    return { success: true };
  }

  async removeNotification(id: string, userId: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid notification ID');
    }

    const query: any = { _id: id };
    if (userId) {
      query.$or = [{ userId }, { userId: '' }, { userId: { $exists: false } }];
    }

    const updated = await this.notificationModel.findOneAndUpdate(
      query,
      {
        $set: {
          isActive: false,
          isDismissed: true,
          isRead: true,
          readAt: new Date(),
        },
      },
      { new: true },
    );

    if (!updated) {
      throw new NotFoundException('Notification not found');
    }

    return { success: true };
  }

  /**
   * Pushes 2 notifications to a requester upon indent fulfillment:
   * 1. Stock Arrived & Available
   * 2. Auto-Issue Request Created on their behalf
   */
  async notifyRequesterStockArrivedAndAutoIssued(params: {
    userId: string;
    itemId: string;
    itemName: string;
    itemCode?: string;
    unit?: string;
    qty: number;
    indentNo: string;
    issueNo?: string;
  }): Promise<void> {
    try {
      const itemObjId = Types.ObjectId.isValid(params.itemId)
        ? new Types.ObjectId(params.itemId)
        : null;

      if (!params.userId || !itemObjId) return;

      const now = new Date();

      // 1. Stock Arrived Notification
      await this.notificationModel.findOneAndUpdate(
        {
          userId: params.userId,
          itemId: itemObjId,
          type: 'STOCK_ARRIVED',
        },
        {
          $set: {
            title: 'Stock Arrived & Available',
            message: `${params.itemName || 'Requested item'} is now available in store (${params.qty} ${params.unit || 'units'} received from Indent ${params.indentNo}).`,
            itemName: params.itemName || '',
            itemCode: params.itemCode || '',
            unit: params.unit || '',
            isRead: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          },
        },
        { upsert: true, new: true },
      );

      // 2. Auto-Issue Raised Notification
      if (params.issueNo) {
        await this.notificationModel.findOneAndUpdate(
          {
            userId: params.userId,
            itemId: itemObjId,
            type: 'AUTO_ISSUE_RAISED',
          },
          {
            $set: {
              title: 'Auto-Issue Request Created',
              message: `Issue request ${params.issueNo} for ${params.qty} ${params.unit || 'units'} has been automatically created on your behalf.`,
              itemName: params.itemName || '',
              itemCode: params.itemCode || '',
              unit: params.unit || '',
              isRead: false,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            },
          },
          { upsert: true, new: true },
        );
      }
    } catch (err: any) {
      console.error(
        '[Notification] Error creating stock arrival notifications:',
        err?.message || err,
      );
    }
  }
}
