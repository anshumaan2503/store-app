import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { StoreCart } from './entities/store-cart.schema';
import { StoreCartConfig } from './entities/store-cart-config.schema';
import { StoreCartHistory } from './entities/store-cart-history.schema';
import { UserService } from 'src/features/user/user.service';

export interface CartConfigData {
  cartTimeoutMinutes: number;
  cartTimeoutEnabled: boolean;
  requestTimeoutDays: number;
  requestTimeoutEnabled: boolean;
  monthEndRevertEnabled: boolean;
  monthEndRevertDays?: number;
  indentApprovalRequired?: boolean;
  grnWorkflowEnabled?: boolean;
  indentAutoCloseDays?: number;
  indentAutoCloseEnabled?: boolean;
  updatedBy?: string;
  updatedAt?: Date;
}

@Injectable()
export class StoreCartService implements OnModuleInit {
  // In-memory cache to guarantee ZERO extra DB load for regular cart requests
  private cachedConfig: CartConfigData = {
    cartTimeoutMinutes: 5,
    cartTimeoutEnabled: true,
    requestTimeoutDays: 7,
    requestTimeoutEnabled: true,
    monthEndRevertEnabled: true,
    monthEndRevertDays: 30,
    indentApprovalRequired: false,
    grnWorkflowEnabled: false,
    indentAutoCloseDays: 30,
    indentAutoCloseEnabled: true,
  };

  constructor(
    @InjectModel(StoreCart.name, 'store')
    private readonly cartModel: Model<StoreCart>,
    @InjectModel(StoreCartConfig.name, 'store')
    private readonly cartConfigModel: Model<StoreCartConfig>,
    @InjectModel(StoreCartHistory.name, 'store')
    private readonly cartHistoryModel: Model<StoreCartHistory>,
    private readonly userService: UserService,
  ) {}

  async onModuleInit() {
    await this.initCartConfig();
  }

  private async initCartConfig(): Promise<void> {
    try {
      const cfg: any = await this.cartConfigModel
        .findOne({ configKey: 'default_cart_config' })
        .lean()
        .exec();

      if (!cfg) {
        const created: any = await this.cartConfigModel.create({
          configKey: 'default_cart_config',
          cartTimeoutMinutes: 5,
          cartTimeoutEnabled: true,
          requestTimeoutDays: 7,
          requestTimeoutEnabled: true,
          monthEndRevertEnabled: true,
        });
        this.cachedConfig = {
          cartTimeoutMinutes: Number(created?.cartTimeoutMinutes) || 5,
          cartTimeoutEnabled: created?.cartTimeoutEnabled !== false,
          requestTimeoutDays: Number(created?.requestTimeoutDays) || 7,
          requestTimeoutEnabled: created?.requestTimeoutEnabled !== false,
          monthEndRevertEnabled: created?.monthEndRevertEnabled !== false,
          monthEndRevertDays: Number(created?.monthEndRevertDays) || 30,
          indentApprovalRequired: Boolean(created?.indentApprovalRequired),
          grnWorkflowEnabled: Boolean(created?.grnWorkflowEnabled),
          indentAutoCloseDays: Number(created?.indentAutoCloseDays) || 30,
          indentAutoCloseEnabled: created?.indentAutoCloseEnabled !== false,
          updatedBy: created?.updatedBy,
          updatedAt: created?.updatedAt,
        };
      } else {
        this.cachedConfig = {
          cartTimeoutMinutes: Number(cfg.cartTimeoutMinutes) || 5,
          cartTimeoutEnabled: cfg.cartTimeoutEnabled !== false,
          requestTimeoutDays: Number(cfg.requestTimeoutDays) || 7,
          requestTimeoutEnabled: cfg.requestTimeoutEnabled !== false,
          monthEndRevertEnabled: cfg.monthEndRevertEnabled !== false,
          monthEndRevertDays: Number(cfg.monthEndRevertDays) || 30,
          indentApprovalRequired: Boolean(cfg.indentApprovalRequired),
          grnWorkflowEnabled: Boolean(cfg.grnWorkflowEnabled),
          indentAutoCloseDays: Number(cfg.indentAutoCloseDays) || 30,
          indentAutoCloseEnabled: cfg.indentAutoCloseEnabled !== false,
          updatedBy: cfg.updatedBy,
          updatedAt: cfg.updatedAt,
        };
      }
    } catch (e) {
      console.error('[StoreCartService] Failed to load cart config on startup:', e);
    }
  }

  // Pure in-memory lookup O(1) - NO extra database query!
  getTimeoutMs(): number | null {
    if (!this.cachedConfig.cartTimeoutEnabled) {
      return null; // Disabled! Items do not auto-revert
    }
    const mins = Math.max(1, this.cachedConfig.cartTimeoutMinutes || 5);
    return mins * 60 * 1000;
  }

  // Pure in-memory lookup O(1) for requested items timeout
  getRequestTimeoutMs(): number | null {
    if (!this.cachedConfig.requestTimeoutEnabled) {
      return null; // Disabled! Requisitions never auto-revert
    }
    const days = Math.max(1, Number(this.cachedConfig.requestTimeoutDays) || 7);
    return days * 24 * 60 * 60 * 1000;
  }

  // Pure in-memory lookup O(1) for month-end unclaimed issue auto-revert
  isMonthEndRevertEnabled(): boolean {
    return this.cachedConfig.monthEndRevertEnabled !== false;
  }

  getMonthEndRevertDays(): number {
    return Math.max(1, Number(this.cachedConfig.monthEndRevertDays) || 30);
  }

  // Indent Approval Switch
  isIndentApprovalRequired(): boolean {
    return this.cachedConfig.indentApprovalRequired === true;
  }

  // GRN Workflow Switch
  isGrnWorkflowEnabled(): boolean {
    return this.cachedConfig.grnWorkflowEnabled === true;
  }

  // Indent Auto-Close Switch & Duration (Days)
  isIndentAutoCloseEnabled(): boolean {
    return this.cachedConfig.indentAutoCloseEnabled !== false;
  }

  getIndentAutoCloseDays(): number {
    return Math.max(1, Number(this.cachedConfig.indentAutoCloseDays) || 30);
  }

  getConfigSync(): CartConfigData {
    return this.cachedConfig;
  }

  async getConfig(): Promise<CartConfigData> {
    return this.cachedConfig;
  }

  async updateConfig(dto: {
    cartTimeoutMinutes?: number;
    cartTimeoutEnabled?: boolean;
    requestTimeoutDays?: number;
    requestTimeoutEnabled?: boolean;
    monthEndRevertEnabled?: boolean;
    monthEndRevertDays?: number;
    indentApprovalRequired?: boolean;
    grnWorkflowEnabled?: boolean;
    indentAutoCloseDays?: number;
    indentAutoCloseEnabled?: boolean;
    updatedBy?: string;
  }): Promise<CartConfigData> {
    const update: any = {};
    if (dto.cartTimeoutMinutes !== undefined) {
      update.cartTimeoutMinutes = Math.max(1, Number(dto.cartTimeoutMinutes) || 5);
    }
    if (dto.cartTimeoutEnabled !== undefined) {
      update.cartTimeoutEnabled = Boolean(dto.cartTimeoutEnabled);
    }
    if (dto.requestTimeoutDays !== undefined) {
      update.requestTimeoutDays = Math.max(1, Number(dto.requestTimeoutDays) || 7);
    }
    if (dto.requestTimeoutEnabled !== undefined) {
      update.requestTimeoutEnabled = Boolean(dto.requestTimeoutEnabled);
    }
    if (dto.monthEndRevertEnabled !== undefined) {
      update.monthEndRevertEnabled = Boolean(dto.monthEndRevertEnabled);
    }
    if (dto.monthEndRevertDays !== undefined) {
      update.monthEndRevertDays = Math.max(1, Number(dto.monthEndRevertDays) || 30);
    }
    if (dto.indentApprovalRequired !== undefined) {
      update.indentApprovalRequired = Boolean(dto.indentApprovalRequired);
    }
    if (dto.grnWorkflowEnabled !== undefined) {
      update.grnWorkflowEnabled = Boolean(dto.grnWorkflowEnabled);
    }
    if (dto.indentAutoCloseDays !== undefined) {
      update.indentAutoCloseDays = Math.max(1, Number(dto.indentAutoCloseDays) || 30);
    }
    if (dto.indentAutoCloseEnabled !== undefined) {
      update.indentAutoCloseEnabled = Boolean(dto.indentAutoCloseEnabled);
    }
    if (dto.updatedBy) {
      update.updatedBy = dto.updatedBy;
    }

    const doc = await this.cartConfigModel
      .findOneAndUpdate(
        { configKey: 'default_cart_config' },
        { $set: update },
        { upsert: true, new: true },
      )
      .lean()
      .exec();

    this.cachedConfig = {
      cartTimeoutMinutes: Number(doc?.cartTimeoutMinutes) || 5,
      cartTimeoutEnabled: doc?.cartTimeoutEnabled !== false,
      requestTimeoutDays: Number(doc?.requestTimeoutDays) || 7,
      requestTimeoutEnabled: doc?.requestTimeoutEnabled !== false,
      monthEndRevertEnabled: doc?.monthEndRevertEnabled !== false,
      monthEndRevertDays: Number(doc?.monthEndRevertDays) || 30,
      indentApprovalRequired: Boolean(doc?.indentApprovalRequired),
      grnWorkflowEnabled: Boolean(doc?.grnWorkflowEnabled),
      indentAutoCloseDays: Number(doc?.indentAutoCloseDays) || 30,
      indentAutoCloseEnabled: doc?.indentAutoCloseEnabled !== false,
      updatedBy: doc?.updatedBy,
      updatedAt: (doc as any)?.updatedAt || new Date(),
    };

    return this.cachedConfig;
  }

  async recordCartHistory(
    entries: {
      itemId: string;
      itemName?: string;
      itemCode?: string;
      unit?: string;
      userId: string;
      userName?: string;
      department?: string;
      quantity: number;
      addedAt: Date;
      revertedAt?: Date;
      revertType?: string;
      remark?: string;
      issNo?: string;
      issueId?: string;
    }[],
  ) {
    if (!entries || entries.length === 0) return;
    try {
      const missingUserIds = Array.from(
        new Set(
          entries
            .filter((e) => !e.userName || !e.department)
            .map((e) => String(e.userId)),
        ),
      );
      let userMap = new Map<string, any>();
      if (missingUserIds.length > 0) {
        userMap = await this.userService.findUsersWithDivisionMap(missingUserIds);
      }
      const docs = entries.map((e) => {
        const u = userMap.get(String(e.userId));
        return {
          itemId: String(e.itemId),
          itemName: e.itemName || '',
          itemCode: e.itemCode || '',
          unit: e.unit || 'PCS',
          userId: String(e.userId),
          userName: e.userName || u?.name || 'User ' + String(e.userId).slice(-4),
          department: e.department || u?.department || 'General Operations',
          quantity: Math.max(1, Number(e.quantity) || 1),
          addedAt: e.addedAt ? new Date(e.addedAt) : new Date(),
          revertedAt: e.revertedAt ? new Date(e.revertedAt) : new Date(),
          revertType: e.revertType || 'AUTO_TIMEOUT_5_MIN',
          issNo: e.issNo || '',
          issueId: e.issueId || '',
          remark:
            e.remark ||
            'Auto-revert: 5 minutes cart hold time limit exceeded. Item returned to available stock.',
        };
      });
      await this.cartHistoryModel.insertMany(docs);
    } catch (err) {
      console.warn('[StoreCartService] recordCartHistory error (non-fatal):', err);
    }
  }

  async getItemCartBreakdown(itemId: string) {
    if (!itemId) return [];
    const now = Date.now();
    const carts = await this.cartModel.find().lean().exec();
    const timeoutMs = this.getTimeoutMs();

    const activeEntries: {
      userId: string;
      quantity: number;
      addedAt: Date;
    }[] = [];
    const userIds: string[] = [];

    for (const cart of carts) {
      for (const item of cart.items || []) {
        const isNotExpired =
          timeoutMs === null ||
          now - new Date(item.addedAt).getTime() < timeoutMs;

        if (String(item.id || '') === itemId && isNotExpired) {
          const qty = Number(item.quantity) || 0;
          if (qty > 0) {
            activeEntries.push({
              userId: cart.userId,
              quantity: qty,
              addedAt: item.addedAt,
            });
            if (cart.userId) userIds.push(cart.userId);
          }
        }
      }
    }

    // Retrieve persistent cart revert & expiration history
    const historyDocs = await this.cartHistoryModel
      .find({ itemId: String(itemId) })
      .sort({ revertedAt: -1 })
      .limit(30)
      .lean()
      .exec();

    for (const h of historyDocs) {
      if (h.userId && !userIds.includes(String(h.userId))) {
        userIds.push(String(h.userId));
      }
    }

    const userMap = await this.userService.findUsersWithDivisionMap(userIds);

    const activeList = activeEntries.map((entry) => {
      const u = userMap.get(entry.userId);
      const remainingSec =
        timeoutMs === null
          ? -1
          : Math.max(
              0,
              Math.round(
                (timeoutMs - (now - new Date(entry.addedAt).getTime())) / 1000,
              ),
            );
      return {
        userId: entry.userId,
        userName: u?.name || 'User ' + entry.userId.slice(-4),
        department: u?.department || 'General Operations',
        quantity: entry.quantity,
        addedAt: entry.addedAt,
        remainingSeconds: remainingSec,
        isExpired: false,
        status: 'IN_CART',
        remark: 'Currently held in user cart',
      };
    });

    const historyList = historyDocs.map((h: any) => {
      const u = userMap.get(String(h.userId));
      const isTransferred = h.revertType === 'TRANSFERRED_TO_REQUESTED';
      const isManual = h.revertType === 'MANUAL_REMOVED';
      let status = 'CART_EXPIRED';
      if (isTransferred) {
        status = 'CART_REQUESTED';
      } else if (isManual) {
        status = 'CART_REMOVED';
      }
      return {
        userId: String(h.userId),
        userName: h.userName || u?.name || 'User ' + String(h.userId).slice(-4),
        department: h.department || u?.department || 'General Operations',
        quantity: h.quantity,
        addedAt: h.addedAt,
        revertedAt: h.revertedAt,
        remainingSeconds: 0,
        isExpired: true,
        status,
        issNo: h.issNo || '',
        issueId: h.issueId || '',
        revertType: h.revertType || 'AUTO_TIMEOUT_5_MIN',
        remark:
          h.remark ||
          (isTransferred
            ? `Transferred from Cart to Requisition #${h.issNo || ''}`
            : isManual
            ? 'Removed from cart manually by requester'
            : 'Auto-revert: 5 minutes cart hold time limit exceeded. Item returned to available stock.'),
      };
    });

    return [...activeList, ...historyList];
  }

  async getItemInCartQuantity(
    itemId: string,
    excludeUserId?: string,
  ): Promise<number> {
    if (!itemId) return 0;
    const now = Date.now();
    const timeoutMs = this.getTimeoutMs();
    const filter: any = { 'items.id': String(itemId) };
    if (excludeUserId) {
      filter.userId = { $ne: String(excludeUserId) };
    }
    const carts = await this.cartModel
      .find(filter)
      .lean()
      .exec();

    let total = 0;
    for (const cart of carts) {
      for (const item of cart.items || []) {
        if (String(item.id || '') === String(itemId)) {
          const isNotExpired =
            timeoutMs === null ||
            now - new Date(item.addedAt).getTime() < timeoutMs;
          if (isNotExpired) {
            total += Number(item.quantity) || 0;
          }
        }
      }
    }
    return total;
  }

  async getCart(userId: string): Promise<any[]> {
    if (!userId) return [];
    const cart = await this.cartModel.findOne({ userId }).exec();
    if (!cart) return [];

    const timeoutMs = this.getTimeoutMs();
    const now = Date.now();
    const validItems: any[] = [];
    const expiredItems: any[] = [];

    for (const item of (cart.items || [])) {
      const isNotExpired =
        timeoutMs === null ||
        now - new Date(item.addedAt).getTime() < timeoutMs;
      if (isNotExpired) {
        validItems.push(item);
      } else {
        expiredItems.push(item);
      }
    }

    if (expiredItems.length > 0) {
      cart.items = validItems as any;
      await cart.save();
      const mins = Math.max(1, Math.round((timeoutMs || 300000) / 60000));
      this.recordCartHistory(
        expiredItems.map((it) => ({
          itemId: String(it.id || ''),
          itemName: it.itemName,
          itemCode: it.itemCode,
          unit: it.unit,
          userId,
          quantity: it.quantity,
          addedAt: it.addedAt,
          revertedAt: new Date(),
          revertType: 'AUTO_TIMEOUT_5_MIN',
          remark: `Auto-revert: ${mins} minutes cart hold timeline reached`,
        })),
      ).catch(() => {});
    }

    return validItems;
  }

  async getAllInCartQuantities(): Promise<Record<string, number>> {
    const now = Date.now();
    const timeoutMs = this.getTimeoutMs();
    const carts = await this.cartModel.find().exec();
    const totals: Record<string, number> = {};

    for (const cart of carts) {
      let modified = false;
      const validItems: any[] = [];
      const expiredItems: any[] = [];

      for (const item of cart.items || []) {
        const isNotExpired =
          timeoutMs === null ||
          now - new Date(item.addedAt).getTime() < timeoutMs;

        if (isNotExpired) {
          validItems.push(item);
          const id = String(item.id || '');
          if (id) {
            totals[id] = (totals[id] || 0) + (Number(item.quantity) || 0);
          }
        } else {
          modified = true;
          expiredItems.push(item);
        }
      }

      if (modified) {
        cart.items = validItems as any;
        await cart.save().catch(() => {});
        if (expiredItems.length > 0 && cart.userId) {
          const mins = Math.max(1, Math.round((timeoutMs || 300000) / 60000));
          this.recordCartHistory(
            expiredItems.map((it) => ({
              itemId: String(it.id || ''),
              itemName: it.itemName,
              itemCode: it.itemCode,
              unit: it.unit,
              userId: cart.userId,
              quantity: it.quantity,
              addedAt: it.addedAt,
              revertedAt: new Date(),
              revertType: 'AUTO_TIMEOUT_5_MIN',
              remark: `Auto-revert: ${mins} minutes cart hold timeline reached`,
            })),
          ).catch(() => {});
        }
      }
    }

    return totals;
  }

  async syncCart(userId: string, items: any[]): Promise<any[]> {
    if (!userId) return [];

    const now = Date.now();
    const timeoutMs = this.getTimeoutMs();
    const existingCart = await this.cartModel.findOne({ userId }).lean().exec();
    const previousItems = existingCart?.items || [];

    const validItems = (items || [])
      .map((item) => {
        let addedAt = item.addedAt ? new Date(item.addedAt) : new Date();
        if (isNaN(addedAt.getTime())) addedAt = new Date();
        return {
          id: String(item.id || item._id || ''),
          itemName: String(item.itemName || ''),
          itemCode: String(item.itemCode || ''),
          unit: String(item.unit || 'PCS'),
          imageUrl: String(item.imageUrl || ''),
          quantity: Number(item.quantity) || 1,
          stockAvailableQuantity: Number(item.stockAvailableQuantity) || 0,
          rackId: item.rackId ? String(item.rackId) : null,
          categoryId: item.categoryId ? String(item.categoryId) : null,
          categoryLabel: item.categoryLabel ? String(item.categoryLabel) : null,
          addedAt,
        };
      })
      .filter(
        (item) =>
          timeoutMs === null || now - item.addedAt.getTime() < timeoutMs,
      );

    // Track items that were removed manually
    const newIds = new Set(validItems.map((v) => v.id));
    const removedItems = previousItems.filter((prev) => !newIds.has(String(prev.id)));
    if (removedItems.length > 0) {
      this.recordCartHistory(
        removedItems.map((it) => ({
          itemId: String(it.id || ''),
          itemName: it.itemName,
          itemCode: it.itemCode,
          unit: it.unit,
          userId,
          quantity: it.quantity,
          addedAt: it.addedAt,
          revertedAt: new Date(),
          revertType: 'MANUAL_REMOVED',
          remark: 'Removed from cart by requester',
        })),
      ).catch(() => {});
    }

    const updated = await this.cartModel
      .findOneAndUpdate(
        { userId },
        { $set: { items: validItems } },
        { upsert: true, new: true },
      )
      .exec();

    return updated?.items || [];
  }

  async clearCart(userId: string): Promise<any[]> {
    if (!userId) return [];
    await this.cartModel
      .findOneAndUpdate(
        { userId },
        { $set: { items: [] } },
        { upsert: true },
      )
      .exec();
    return [];
  }
}
