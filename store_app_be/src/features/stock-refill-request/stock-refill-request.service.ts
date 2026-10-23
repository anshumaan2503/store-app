import {
  BadRequestException,
  forwardRef,
  Inject,
  Injectable,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  IndentRaise,
  IndentRaiseDocument,
  StockRefillRequest,
  StockRefillRequestDocument,
} from './schemas/stock-refill-request.schema';
import {
  IndentDraft,
  IndentDraftDocument,
} from './schemas/indent-draft.schema';
import { StoreNewItem } from '../new-store/store-items/store-item/entities/store-item.schema';
import { Counter } from '../new-store/common/entities/counter.schema';
import {
  CreateIndentRaiseDto,
  ReviewIndentRaiseDto,
  UpdateIndentQtyDto,
  ConsolidatedStoreApproveDto,
  ApproveIndentItemDto,
  ApproveWholeIndentDto,
} from './dto/create-indent-raise.dto';
import {
  AddIndentDraftItemDto,
  SubmitCombinedIndentDto,
  UpdateIndentDraftItemDto,
} from './dto/indent-draft.dto';
import {
  Rack,
  RackDocument,
} from '../new-store/locations/rack/entities/rack.schema';
import {
  ItemRackQty,
  ItemRackQtyDocument,
} from '../new-store/locations/rack/entities/item-rack-qty.schema';
import { StoreNewItemService } from '../new-store/store-items/store-item/store-item.service';
import { StoreCartService } from '../new-store/store-items/store-cart/store-cart.service';
import { IssueService } from '../new-store/store-items/store-item-issue/store-item-issue.service';
import { StoreNotificationService } from '../store-notification/store-notification.service';

@Injectable()
export class IndentRaiseService implements OnModuleInit, OnModuleDestroy {
  private eodTimer: NodeJS.Timeout | null = null;

  onModuleInit() {
    this.scheduleNextEndOfDayRun();
  }

  onModuleDestroy() {
    if (this.eodTimer) {
      clearTimeout(this.eodTimer);
      this.eodTimer = null;
    }
  }

  /**
   * Schedules the next End-of-Day auto-indent run at 11:59 PM (23:59:00).
   * Automatically calculates remaining time and recurses daily.
   */
  private scheduleNextEndOfDayRun() {
    const now = new Date();
    const next2359 = new Date(now);
    next2359.setHours(23, 59, 0, 0);

    // If already past 23:59:00 today, schedule for tomorrow 23:59:00
    if (now.getTime() >= next2359.getTime()) {
      next2359.setDate(next2359.getDate() + 1);
    }

    const msUntilTarget = next2359.getTime() - now.getTime();
    console.log(
      `[EOD Auto-Indent Scheduler] Initialized. Next run scheduled for ${next2359.toLocaleString()} (in ${Math.round(msUntilTarget / 60000)} minutes).`,
    );

    this.eodTimer = setTimeout(async () => {
      try {
        console.log('[EOD Auto-Indent Scheduler] Running 11:59 PM nightly auto-indent job...');
        await this.runEndOfDayAutoIndentScheduler();
        await this.autoCloseExpiredIndents();
      } catch (err) {
        console.error('[EOD Auto-Indent Scheduler] Error during nightly auto-indent execution:', err);
      } finally {
        this.scheduleNextEndOfDayRun();
      }
    }, msUntilTarget);
  }

  constructor(
    @InjectModel(IndentRaise.name, 'store')
    private readonly indentModel: Model<IndentRaiseDocument>,
    @InjectModel(IndentDraft.name, 'store')
    private readonly indentDraftModel: Model<IndentDraftDocument>,
    @InjectModel(StoreNewItem.name, 'store')
    private readonly itemModel: Model<StoreNewItem>,
    @InjectModel(Counter.name, 'store')
    private readonly counterModel: Model<Counter>,
    @InjectModel(Rack.name, 'store')
    private readonly rackModel: Model<RackDocument>,
    @InjectModel(ItemRackQty.name, 'store')
    private readonly itemRackQtyModel: Model<ItemRackQtyDocument>,
    @Inject(forwardRef(() => StoreNewItemService))
    private readonly storeItemService: StoreNewItemService,
    @Inject(forwardRef(() => StoreCartService))
    @Optional()
    private readonly storeCartService?: StoreCartService,
    @Inject(forwardRef(() => IssueService))
    @Optional()
    private readonly issueService?: IssueService,
    @Inject(forwardRef(() => StoreNotificationService))
    @Optional()
    private readonly notificationService?: StoreNotificationService,
  ) {}

  /**
   * Generates a unique, collision-safe indent number formatted as IND-YYYYMMDD-0001.
   * Uses MongoDB's atomic findOneAndUpdate with $inc to guarantee uniqueness under concurrency.
   */
  private async generateIndentNumber(): Promise<string> {
    const today = new Date();
    const y = today.getFullYear();
    const m = (today.getMonth() + 1).toString().padStart(2, '0');
    const d = today.getDate().toString().padStart(2, '0');
    const prefix = `IND-${y}${m}${d}`;
    const counterKey = `indent_${y}${m}${d}`;

    // Ensure counter is initialized above any pre-existing records for today
    const exists = await this.counterModel.exists({ key: counterKey });
    if (!exists) {
      const existingLatest = await this.indentModel
        .findOne({
          $or: [
            { indentNumber: { $regex: `^${prefix}` } },
            { requestNo: { $regex: `^${prefix}` } },
          ],
        })
        .sort({ indentNumber: -1, requestNo: -1 })
        .select({ indentNumber: 1, requestNo: 1 })
        .lean()
        .exec();

      let initialSeq = 0;
      if (existingLatest) {
        const lastCode =
          existingLatest.indentNumber || existingLatest.requestNo || '';
        const parts = lastCode.split('-');
        const lastNum = parseInt(parts[parts.length - 1], 10);
        if (!isNaN(lastNum) && lastNum > 0) {
          initialSeq = lastNum;
        }
      }

      try {
        await this.counterModel.updateOne(
          { key: counterKey },
          { $setOnInsert: { key: counterKey, seq: initialSeq } },
          { upsert: true },
        );
      } catch (err) {
        // Concurrently inserted by another process; safe to ignore
      }
    }

    // Atomic increment operation guaranteed by MongoDB document lock
    const counterDoc = await this.counterModel.findOneAndUpdate(
      { key: counterKey },
      { $inc: { seq: 1 } },
      { new: true, upsert: true },
    );

    return `${prefix}-${counterDoc.seq.toString().padStart(4, '0')}`;
  }

  /**
   * Raises a new Indent for a material.
   * Business Rules:
   * 1. Resolves authoritative item master data from StoreNewItem.
   * 2. Authoritatively verifies that stock is in LOW or ZERO condition:
   *    (availableQuantity <= threshold OR availableQuantity <= 0).
   *    Where threshold = (totalStock * 0.1) < 1 ? 1 : (totalStock * 0.1).
   * 3. Snapshots all 20 reference fields + application workflow fields.
   * 4. Synchronizes legacy fields (requestNo, requestedQty, unit, itemName) for 100% backward compatibility.
   * 5. DATA SAFETY: Indent creation strictly does NOT modify physical inventory.
   */
  async create(dto: CreateIndentRaiseDto, user: any) {
    if (!dto.itemId || !Types.ObjectId.isValid(dto.itemId)) {
      throw new BadRequestException('Invalid or missing item ID');
    }

    // 1. Authoritative item master lookup
    const item = await this.itemModel.findById(dto.itemId);
    if (!item) {
      throw new NotFoundException('Store item not found');
    }

    // 2. Authoritative stock condition & maximum quantity evaluation
    const avail =
      typeof item.stockAvailableQuantity === 'number'
        ? item.stockAvailableQuantity
        : 0;
    const total =
      typeof item.totalStockQuantity === 'number'
        ? item.totalStockQuantity
        : 0;

    const currentStock = Math.max(0, avail);

    const maxQty =
      typeof item.maxCapacity === 'number' && item.maxCapacity > 0
        ? item.maxCapacity
        : typeof (item as any).maxQuantity === 'number' && (item as any).maxQuantity > 0
          ? (item as any).maxQuantity
          : 0;

    // Validate indent quantity (support both indentQty and requestedQty) early
    const rawQty = dto.indentQty ?? dto.requestedQty;
    const qty = Number(rawQty);
    if (!rawQty || isNaN(qty) || qty < 1) {
      throw new BadRequestException(
        'Indent quantity must be a valid number greater than or equal to 1',
      );
    }

    if (maxQty > 0) {
      // Rule: If item has reached maximum quantity, manual indent request should NOT be generated
      if (currentStock >= maxQty) {
        throw new BadRequestException(
          `Cannot raise indent: Material "${item.itemName || item.itemCode}" has reached its maximum quantity of ${maxQty} (Current stock: ${currentStock}). Manual indent request cannot be generated.`,
        );
      }
    }

    if (maxQty > 0) {
      if (qty > maxQty * 1.05) {
        throw new BadRequestException(
          `Cannot raise indent: Requested quantity (${qty}) exceeds the allowable maximum capacity of ${maxQty} ${item.unit || 'units'}.`,
        );
      }
    } else {
      // Fallback: Authoritative low-stock threshold formula when maximum quantity is not configured
      const minConfig =
        typeof item.minStockQuantity === 'number' && item.minStockQuantity > 0
          ? item.minStockQuantity
          : 0;
      const threshold =
        minConfig > 0 ? minConfig : total * 0.1 < 1 ? 1 : total * 0.1;

      // Indent Raise is strictly restricted to LOW or ZERO stock items
      if (avail > threshold && avail > 0) {
        throw new BadRequestException(
          `Cannot raise indent: Material "${item.itemName || item.itemCode}" is not in low or zero stock condition. Available stock is ${avail}, which exceeds the low-stock threshold of ${threshold}. Indent raise is only permitted for low or zero stock materials.`,
        );
      }
    }

    // 4. Generate collision-safe atomic indent number
    const indentNumber = await this.generateIndentNumber();

    // 5. Authoritative item master snapshots
    const itemCode = (item.itemCode || '').trim();
    const itemName = (item.itemName || '').trim();
    const itemDescription =
      (dto.itemDescription || '').trim() ||
      (item.description || '').trim() ||
      itemName;
    const unitOfMeasure = (item.unit || dto.unitOfMeasure || '').trim();
    const make = (dto.make || '').trim();
    const techSpec = (dto.techSpec || '').trim();
    const hsnCode = (dto.hsnCode || '').trim();
    const lineNumber =
      dto.lineNumber && dto.lineNumber >= 1 ? Number(dto.lineNumber) : 1;

    // Indent quantities
    const indentQty = qty;
    const preReqQty =
      dto.preReqQty !== undefined && !isNaN(Number(dto.preReqQty))
        ? Number(dto.preReqQty)
        : 0;
    const preqQty =
      dto.preqQty !== undefined && !isNaN(Number(dto.preqQty))
        ? Number(dto.preqQty)
        : 0;
    // Client-provided dto.balanceQty MUST NOT override the authoritative database value.
    // Stock quantities are strictly calculated from authoritative StoreNewItem:
    const balanceQty = avail;
    const currentAvailableQty = avail;
    const currentTotalQty = total;

    // Document context
    const documentCategory = (dto.documentCategory || '').trim() || 'ITEM_MASTER';
    const company = (dto.company || '').trim() || 'STORE';
    const costCenter = (dto.costCenter || '').trim() || 'MAIN_STORE';
    const documentDate = dto.documentDate
      ? new Date(dto.documentDate)
      : new Date();
    const documentType = (dto.documentType || '').trim() || 'INDENT';

    // Requester context derived securely from req.user
    const requestedBy = user?.name || user?.email || 'Store User';
    const requesterId = (user?._id || user?.uid || '').toString();
    const reason = (dto.reason || '').trim();
    const indentType = (dto.indentType || '').trim() || 'STORE_REFILL';
    const sourceIssueId = (dto.sourceIssueId || '').trim();

    const now = new Date();

    const doc = new this.indentModel({
      indentType,
      sourceIssueId,
      // Reference business fields
      indentNumber,
      itemCode,
      itemDescription,
      make,
      techSpec,
      unitOfMeasure,
      lineNumber,
      createdOn: now,
      lastChangedOn: now,
      indentQty,
      preReqQty,
      preqQty,
      balanceQty,
      documentCategory,
      company,
      costCenter,
      documentDate,
      documentType,
      requestedBy,
      hsnCode,

      // Workflow & Authorization fields
      itemId: item._id,
      requesterId,
      status: this.storeCartService?.isIndentApprovalRequired() ? 'PENDING' : 'APPROVED',
      reason,
      currentAvailableQty: avail,
      currentTotalQty: total,
      timeline: [
        {
          action: 'CREATED',
          title: 'Indent Raised',
          description: this.storeCartService?.isIndentApprovalRequired()
            ? (reason ? `Requested: ${reason}` : 'Submitted for approver review')
            : 'Auto-approved (Indent approval disabled in system settings)',
          actorName: requestedBy,
          timestamp: now,
        },
        ...(this.storeCartService?.isIndentApprovalRequired()
          ? []
          : [
              {
                action: 'APPROVED',
                title: 'Auto-Approved',
                description: 'Directly available in Receive section',
                actorName: 'System Settings',
                timestamp: now,
              },
            ]),
      ],

      // Backward-compatibility mirror fields
      requestNo: indentNumber,
      itemName,
      unit: unitOfMeasure,
      requestedQty: indentQty,
    });

    // DATA SAFETY: Indent raise creation strictly does NOT modify physical inventory.
    const saved = await doc.save();
    return this.normalizeOutput(saved);
  }

  /**
   * Evaluates an item's available stock against its configured minimum stock threshold (minStockQuantity).
   *
   * NEW ARCHITECTURE (End-of-Day Scheduler):
   * - Auto-indents are strictly NOT raised immediately when an item reaches minimum quantity.
   * - Instead, the system maintains the item as "isIndentReady: true" (indent-ready state).
   * - At 11:59 PM nightly, the End-of-Day scheduler evaluates all indent-ready items and combines
   *   them into a single consolidated indent requisition.
   */
  async checkAndTriggerAutoIndent(
    itemId: string | Types.ObjectId,
    currentAvailable?: number,
    operatorInfo?: { name?: string; id?: string },
  ): Promise<any | null> {
    if (!itemId) return null;

    const item = await this.itemModel.findById(itemId);
    if (!item || item.isScrap) return null;

    const minStock =
      typeof item.minStockQuantity === 'number' && item.minStockQuantity > 0
        ? item.minStockQuantity
        : 0;

    // Only items with an explicitly configured minimum threshold trigger auto-refills
    if (minStock <= 0) return null;

    const avail =
      typeof currentAvailable === 'number'
        ? currentAvailable
        : typeof item.stockAvailableQuantity === 'number'
          ? item.stockAvailableQuantity
          : 0;

    // Active non-expired in-cart units for this item across other users (ignoring user submitting checkout)
    const inCart = this.storeCartService
      ? await this.storeCartService.getItemInCartQuantity(
          String(item._id),
          operatorInfo?.id,
        )
      : 0;

    // Combined stock: Available Stock + In-Cart Quantity
    const combinedStock = avail + inCart;

    // Check if combined stock reached/fell below minimum threshold
    const isReady = combinedStock <= minStock;

    if (item.isIndentReady !== isReady) {
      await this.itemModel.findByIdAndUpdate(item._id, { isIndentReady: isReady });
      if (isReady) {
        console.log(
          `[Indent-Ready] Item "${item.itemName}" (${item.itemCode}) reached min stock (${combinedStock} <= ${minStock}). Maintained as INDENT-READY for 11:59 PM batch.`,
        );
      }
    }

    return {
      isIndentReady: isReady,
      itemId: String(item._id),
      combinedStock,
      minStock,
    };
  }

  /**
   * Automatically cancels/rejects a PENDING system-generated auto-indent if stock is restored
   * above the minimum threshold (e.g., when an issue requisition is rejected, cancelled, or expires).
   */
  async checkAndCancelAutoIndentIfStockRestored(
    itemId: string | Types.ObjectId,
    currentAvailable?: number,
    systemNote?: string,
  ): Promise<any | null> {
    if (!itemId) return null;

    const item = await this.itemModel.findById(itemId);
    if (!item) return null;

    const minStock =
      typeof item.minStockQuantity === 'number' && item.minStockQuantity > 0
        ? item.minStockQuantity
        : 0;

    if (minStock <= 0) return null;

    const avail =
      typeof currentAvailable === 'number'
        ? currentAvailable
        : typeof item.stockAvailableQuantity === 'number'
          ? item.stockAvailableQuantity
          : 0;

    const inCart = this.storeCartService
      ? await this.storeCartService.getItemInCartQuantity(String(item._id))
      : 0;

    const combinedStock = avail + inCart;

    const maxQty =
      typeof item.maxCapacity === 'number' && item.maxCapacity > 0
        ? item.maxCapacity
        : typeof (item as any).maxQuantity === 'number' && (item as any).maxQuantity > 0
          ? (item as any).maxQuantity
          : 0;

    const isAboveMin = combinedStock > minStock;
    const isAtOrAboveMax = maxQty > 0 && combinedStock >= maxQty;

    // Only cancel or reduce if combined stock has recovered ABOVE minimum threshold OR reached max capacity
    if (!isAboveMin && !isAtOrAboveMax) {
      return null;
    }

    // Reset indent-ready state since stock has recovered above minimum
    if (item.isIndentReady && isAboveMin) {
      await this.itemModel.findByIdAndUpdate(item._id, { isIndentReady: false });
    }

    // Find any PENDING auto-refill or shortage indent for this item
    const pendingAutoIndent = await this.indentModel.findOne({
      $and: [
        { $or: [{ itemId: item._id }, { itemId: String(item._id) }] },
        { status: 'PENDING' },
        {
          $or: [
            { requestedBy: { $regex: /SYSTEM/i } },
            { reason: { $regex: /Auto Refill/i } },
            { reason: { $regex: /Auto-Indent/i } },
            { indentType: 'AUTO_REFILL' },
            { indentType: 'ISSUE_SHORTAGE' },
          ],
        },
      ],
    });

    if (!pendingAutoIndent) return null;

    const now = new Date();

    if (isAtOrAboveMax) {
      // Stock already meets or exceeds max capacity; cancel the indent completely
      pendingAutoIndent.status = 'REJECTED';
      pendingAutoIndent.reviewRemarks =
        systemNote ||
        `Auto-cancelled by System: Stock restored to ${avail} (combined: ${combinedStock}), reaching maximum capacity (${maxQty}).`;
      pendingAutoIndent.reviewedBy = 'SYSTEM (Auto Revert)';
      pendingAutoIndent.reviewedById = 'system';
      pendingAutoIndent.reviewedAt = now;
      pendingAutoIndent.lastChangedOn = now;
      pendingAutoIndent.timeline = Array.isArray(pendingAutoIndent.timeline)
        ? pendingAutoIndent.timeline
        : [];
      pendingAutoIndent.timeline.push({
        action: 'REJECTED',
        title: 'Auto-Cancelled by System',
        description: pendingAutoIndent.reviewRemarks,
        actorName: 'SYSTEM',
        timestamp: now,
      });
      const saved = await pendingAutoIndent.save();
      return this.normalizeOutput(saved);
    } else if (
      maxQty > 0 &&
      combinedStock + (pendingAutoIndent.indentQty || 0) > maxQty
    ) {
      // Scale down the indent quantity to maxCapacity - combinedStock
      const oldQty = pendingAutoIndent.indentQty || 0;
      const newQty = maxQty - combinedStock;
      pendingAutoIndent.indentQty = newQty;
      pendingAutoIndent.requestedQty = newQty;
      pendingAutoIndent.timeline = Array.isArray(pendingAutoIndent.timeline)
        ? pendingAutoIndent.timeline
        : [];
      pendingAutoIndent.timeline.push({
        action: 'QTY_AUTO_REDUCED',
        title: 'Quantity Auto-Reduced on Stock Reversion',
        description: `Quantity automatically reduced from ${oldQty} to ${newQty} ${item.unit || 'units'} to respect maximum capacity (${maxQty}) after stock was restored.`,
        actorName: 'SYSTEM',
        timestamp: now,
      });
      const saved = await pendingAutoIndent.save();
      return this.normalizeOutput(saved);
    } else if (isAboveMin) {
      // Stock recovered above minimum threshold
      pendingAutoIndent.status = 'REJECTED';
      pendingAutoIndent.reviewRemarks =
        systemNote ||
        `Auto-cancelled by System: Stock restored to ${avail} (combined: ${combinedStock}), exceeding minimum threshold (${minStock}).`;
      pendingAutoIndent.reviewedBy = 'SYSTEM (Auto Revert)';
      pendingAutoIndent.reviewedById = 'system';
      pendingAutoIndent.reviewedAt = now;
      pendingAutoIndent.lastChangedOn = now;
      pendingAutoIndent.timeline = Array.isArray(pendingAutoIndent.timeline)
        ? pendingAutoIndent.timeline
        : [];
      pendingAutoIndent.timeline.push({
        action: 'REJECTED',
        title: 'Auto-Cancelled by System',
        description: pendingAutoIndent.reviewRemarks,
        actorName: 'SYSTEM',
        timestamp: now,
      });
      const saved = await pendingAutoIndent.save();
      return this.normalizeOutput(saved);
    }

    return null;
  }

  /**
   * End-of-Day Scheduler: Executes nightly at 11:59 PM (or on-demand).
   * 1. Evaluates all active items where (stockAvailableQuantity + inCart) <= minStockQuantity.
   * 2. Automatically calculates required indent quantities.
   * 3. Combines ALL eligible items into a single consolidated indent (shared groupIndentNumber).
   * 4. Moves the consolidated indent to the approval workflow (status: PENDING).
   */
  async runEndOfDayAutoIndentScheduler(): Promise<{
    success: boolean;
    eligibleItemCount: number;
    groupIndentNumber?: string;
    indents?: any[];
    msg: string;
  }> {
    try {
      console.log('[EOD Indent Scheduler] Starting End-of-Day auto-indent evaluation...');

      // 1. Find all active products with an active minimum stock threshold
      const items = await this.itemModel
        .find({
          isScrap: { $ne: true },
          minStockQuantity: { $gt: 0 },
        })
        .exec();

      const eligibleItems: Array<{
        item: any;
        avail: number;
        inCart: number;
        combinedStock: number;
        minStock: number;
        indentQty: number;
      }> = [];

      for (const item of items) {
        const minStock =
          typeof item.minStockQuantity === 'number' ? item.minStockQuantity : 0;
        if (minStock <= 0) continue;

        const avail =
          typeof item.stockAvailableQuantity === 'number'
            ? item.stockAvailableQuantity
            : 0;
        const inCart = this.storeCartService
          ? await this.storeCartService.getItemInCartQuantity(String(item._id))
          : 0;

        const combinedStock = avail + inCart;

        if (combinedStock <= minStock) {
          // Maintain indent-ready flag
          await this.itemModel.findByIdAndUpdate(item._id, { isIndentReady: true });

          // Avoid duplicate auto-refill: Check if an active AUTO-REFILL indent already exists for this item
          const existingActive = await this.indentModel
            .findOne({
              $and: [
                { $or: [{ itemId: item._id }, { itemId: String(item._id) }] },
                {
                  $or: [
                    { indentType: 'AUTO_REFILL' },
                    { requestedBy: 'Automatic' },
                    { requestedBy: /Auto/i },
                    { isAutoRefill: true },
                  ],
                },
                {
                  $or: [
                    { status: 'PENDING' },
                    { status: 'DEPT_APPROVED' },
                    { status: 'APPROVED', stockCredited: { $ne: true } },
                  ],
                },
              ],
            })
            .lean()
            .exec();

          if (existingActive) {
            console.log(
              `[EOD Indent Scheduler] Item "${item.itemName}" already has active auto-refill indent #${existingActive.indentNumber} (${existingActive.status}). Skipping duplicate.`,
            );
            continue;
          }

          // Calculate required indent quantity:
          // Formula: (maxCapacity / 2) - combinedStock (or defaultRefillQuantity / minStock)
          let indentQty = 1;
          const maxQty =
            typeof item.maxCapacity === 'number' && item.maxCapacity > 0
              ? item.maxCapacity
              : 0;
          if (maxQty > 0) {
            const halfMax = Math.ceil(maxQty / 2);
            const calculatedQty = halfMax - combinedStock;
            if (calculatedQty > 0) {
              indentQty = calculatedQty;
            } else if (
              item.defaultRefillQuantity &&
              item.defaultRefillQuantity > 0
            ) {
              indentQty = item.defaultRefillQuantity;
            } else {
              indentQty = Math.max(1, minStock);
            }
          } else if (
            item.defaultRefillQuantity &&
            item.defaultRefillQuantity > 0
          ) {
            indentQty = item.defaultRefillQuantity;
          } else {
            indentQty = Math.max(1, minStock);
          }

          eligibleItems.push({
            item,
            avail,
            inCart,
            combinedStock,
            minStock,
            indentQty,
          });
        } else {
          if (item.isIndentReady) {
            await this.itemModel.findByIdAndUpdate(item._id, { isIndentReady: false });
          }
        }
      }

      if (eligibleItems.length === 0) {
        console.log('[EOD Indent Scheduler] No items qualified for End-of-Day auto-indent.');
        return {
          success: true,
          eligibleItemCount: 0,
          msg: 'No items currently qualify for End-of-Day auto-indent (all items have adequate stock).',
        };
      }

      // 2. Combine all eligible items into a SINGLE consolidated indent requisition
      const baseIndentNumber = await this.generateIndentNumber();
      const now = new Date();
      const createdDocs: any[] = [];

      for (let i = 0; i < eligibleItems.length; i++) {
        const entry = eligibleItems[i];
        const lineNumber = i + 1;
        const lineIndentNumber =
          i === 0 ? baseIndentNumber : await this.generateIndentNumber();
        const item = entry.item;

        const itemCode = (item.itemCode || '').trim();
        const itemName = (item.itemName || '').trim();
        const itemDescription = (item.description || '').trim() || itemName;
        const unitOfMeasure = (item.unit || '').trim() || 'NOS';
        const total =
          typeof item.totalStockQuantity === 'number'
            ? item.totalStockQuantity
            : 0;

        const doc = new this.indentModel({
          indentType: 'AUTO_REFILL',
          indentNumber: lineIndentNumber,
          groupIndentNumber: baseIndentNumber,
          itemCode,
          itemDescription,
          make: '',
          techSpec: '',
          unitOfMeasure,
          lineNumber,
          createdOn: now,
          lastChangedOn: now,
          createdAt: now,
          updatedAt: now,
          indentQty: entry.indentQty,
          preReqQty: 0,
          preqQty: 0,
          balanceQty: entry.avail,
          documentCategory: 'ITEM_MASTER',
          company: 'STORE',
          costCenter: 'MAIN_STORE',
          documentDate: now,
          documentType: 'INDENT',
          requestedBy: 'Automatic',
          hsnCode: '',

          itemId: item._id,
          requesterId: 'system',
          status: 'DEPT_APPROVED',
          deptApprovedAt: now,
          deptApprovedBy: 'Automatic (Night Scheduler)',
          deptApprovedById: 'system',
          reason: `EOD Auto-Indent: Combined stock (${entry.combinedStock} = Avail ${entry.avail} + Cart ${entry.inCart}) <= min threshold (${entry.minStock}).`,
          currentAvailableQty: entry.avail,
          currentTotalQty: total,
          stockCredited: false,
          timeline: [
            {
              action: 'AUTO_REFILL_CREATED',
              title: 'Night Auto-Refill Generated',
              description: `System evaluated low stock and calculated (max/2 - available): ${entry.indentQty} ${unitOfMeasure}`,
              actorName: 'Automatic',
              timestamp: now,
            },
            {
              action: 'DEPT_APPROVED',
              title: 'Ready for Store Consolidation',
              description: 'System-generated indent automatically ready for Store Incharge consolidation & approval',
              actorName: 'Automatic',
              timestamp: now,
            },
          ],

          // Legacy mirrors
          requestNo: lineIndentNumber,
          itemName,
          unit: unitOfMeasure,
          requestedQty: entry.indentQty,
        });

        const saved = await doc.save();
        createdDocs.push(saved);

        // Reset isIndentReady because indent is now officially submitted to approval workflow
        await this.itemModel.findByIdAndUpdate(item._id, { isIndentReady: false });
      }

      console.log(
        `[EOD Indent Scheduler] Successfully generated consolidated indent #${baseIndentNumber} with ${createdDocs.length} items.`,
      );

      return {
        success: true,
        eligibleItemCount: createdDocs.length,
        groupIndentNumber: baseIndentNumber,
        indents: createdDocs.map((d) => this.normalizeOutput(d)),
        msg: `Consolidated End-of-Day Indent #${baseIndentNumber} generated with ${createdDocs.length} item(s) and moved to approval workflow.`,
      };
    } catch (err: any) {
      console.error('[EOD Indent Scheduler] Error executing End-of-Day scheduler:', err);
      throw err;
    }
  }

  /**
   * Auto-Close Indents older than the Super-Admin configured timeout (default: 30 days / 1 month).
   * Runs nightly as part of the store housekeeping schedule, and can also be triggered on-demand.
   */
  async autoCloseExpiredIndents(): Promise<{
    closedCount: number;
    cutoffDate: Date;
    days: number;
    enabled: boolean;
  }> {
    const isEnabled = this.storeCartService?.isIndentAutoCloseEnabled() ?? true;
    const days = this.storeCartService?.getIndentAutoCloseDays() ?? 30;

    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    if (!isEnabled) {
      return { closedCount: 0, cutoffDate, days, enabled: false };
    }

    const filter: any = {
      status: { $in: ['PENDING', 'DEPT_APPROVED'] },
      stockCredited: { $ne: true },
      createdAt: { $lte: cutoffDate },
    };

    const staleIndents = await this.indentModel.find(filter).exec();
    if (!staleIndents || staleIndents.length === 0) {
      return { closedCount: 0, cutoffDate, days, enabled: true };
    }

    const now = new Date();
    for (const ind of staleIndents) {
      ind.status = 'CLOSED';
      ind.reviewRemarks = `Auto-closed by system: Indent remained unfulfilled for over ${days} days (1 month expiry policy).`;
      ind.reviewedBy = 'SYSTEM (Auto-Close Policy)';
      ind.reviewedById = 'system';
      ind.reviewedAt = now;
      ind.lastChangedOn = now;
      ind.timeline = Array.isArray(ind.timeline) ? ind.timeline : [];
      ind.timeline.push({
        action: 'CLOSED',
        title: 'Auto-Closed after 1 Month',
        description: `Indent automatically closed after exceeding the allowable ${days}-day window without fulfillment.`,
        actorName: 'SYSTEM',
        timestamp: now,
      });
      await ind.save();
    }

    console.log(
      `[Auto-Close Policy] Successfully closed ${staleIndents.length} expired indents older than ${days} days (${cutoffDate.toISOString()}).`,
    );
    return { closedCount: staleIndents.length, cutoffDate, days, enabled: true };
  }

  /**
   * Retrieves all items currently qualifying as "indent-ready" (Available + Cart <= MinStock)
   * awaiting the 11:59 PM End-of-Day batch scheduler.
   */
  async getIndentReadyItems(): Promise<any[]> {
    const items = await this.itemModel
      .find({
        isScrap: { $ne: true },
        minStockQuantity: { $gt: 0 },
      })
      .lean()
      .exec();

    const readyItems: any[] = [];

    for (const item of items) {
      const minStock =
        typeof item.minStockQuantity === 'number' ? item.minStockQuantity : 0;
      if (minStock <= 0) continue;

      const avail =
        typeof item.stockAvailableQuantity === 'number'
          ? item.stockAvailableQuantity
          : 0;
      const inCart = this.storeCartService
        ? await this.storeCartService.getItemInCartQuantity(String(item._id))
        : 0;

      const combinedStock = avail + inCart;

      if (combinedStock <= minStock) {
        const existingPending = await this.indentModel
          .findOne({
            $or: [{ itemId: item._id }, { itemId: String(item._id) }],
            status: 'PENDING',
          })
          .lean()
          .exec();

        let indentQty = 1;
        const maxQty =
          typeof item.maxCapacity === 'number' && item.maxCapacity > 0
            ? item.maxCapacity
            : 0;
        if (maxQty > 0) {
          const halfMax = Math.ceil(maxQty / 2);
          indentQty = Math.max(1, halfMax - combinedStock);
        } else {
          indentQty = Math.max(1, minStock);
        }

        readyItems.push({
          itemId: String(item._id),
          itemName: item.itemName,
          itemCode: item.itemCode,
          unit: item.unit,
          availableStock: avail,
          inCartQuantity: inCart,
          combinedStock,
          minimumStock: minStock,
          suggestedIndentQty: indentQty,
          hasExistingPendingIndent: !!existingPending,
          existingPendingIndentNumber: existingPending?.indentNumber,
        });
      }
    }

    return readyItems;
  }

  /**
   * Retrieves all indents with optional status, search, itemId, and uncredited filters.
   */
  async findAll(
    status?: string,
    search?: string,
    itemId?: string,
    uncredited?: boolean,
  ) {
    const filter: any = {};
    if (status && status.toUpperCase() !== 'ALL') {
      const parts = status.split(',').map((s) => s.trim().toUpperCase());
      if (parts.length > 1) {
        filter.status = { $in: parts };
      } else {
        filter.status = parts[0];
      }
    }
    if (uncredited) {
      filter.stockCredited = { $ne: true };
    }
    if (itemId) {
      const cleanId = String(itemId).trim();
      if (Types.ObjectId.isValid(cleanId)) {
        filter.$or = [
          { itemId: new Types.ObjectId(cleanId) },
          { itemId: cleanId },
        ];
      } else {
        filter.itemId = cleanId;
      }
    }
    if (search && search.trim()) {
      const q = search.trim();
      const searchConditions = [
        { indentNumber: { $regex: q, $options: 'i' } },
        { requestNo: { $regex: q, $options: 'i' } },
        { itemCode: { $regex: q, $options: 'i' } },
        { itemDescription: { $regex: q, $options: 'i' } },
        { itemName: { $regex: q, $options: 'i' } },
        { make: { $regex: q, $options: 'i' } },
        { techSpec: { $regex: q, $options: 'i' } },
        { requestedBy: { $regex: q, $options: 'i' } },
        { reason: { $regex: q, $options: 'i' } },
        { documentCategory: { $regex: q, $options: 'i' } },
        { documentType: { $regex: q, $options: 'i' } },
        { hsnCode: { $regex: q, $options: 'i' } },
      ];
      if (filter.$or) {
        filter.$and = [{ $or: filter.$or }, { $or: searchConditions }];
        delete filter.$or;
      } else {
        filter.$or = searchConditions;
      }
    }

    const docs = await this.indentModel
      .find(filter)
      .sort({ createdOn: -1, createdAt: -1, _id: -1 })
      .exec();

    return docs.map((doc) => this.normalizeOutput(doc));
  }

  /**
   * Retrieves a single indent record by ID.
   */
  async findOne(id: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id).exec();
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    return this.normalizeOutput(doc);
  }

  /**
   * Approves an indent request.
   * If directStockIn is requested, simultaneously credits physical stock into a rack.
   */
  async approve(id: string, dto: ReviewIndentRaiseDto, user: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    if (doc.status !== 'PENDING' && doc.status !== 'DEPT_APPROVED') {
      throw new BadRequestException(
        `Cannot approve indent. Current status is already ${doc.status}`,
      );
    }

    const now = new Date();

    // Step 2: Department Approval (If status is PENDING and not direct store approval)
    const isDeptApproval =
      doc.status === 'PENDING' && !(dto as any)?.isStoreApproval;

    if (isDeptApproval) {
      doc.status = 'DEPT_APPROVED';
      doc.deptApprovedBy = user?.name || user?.email || 'Department Approver';
      doc.deptApprovedById = (user?._id || user?.uid || '').toString();
      doc.deptApprovedAt = now;
      doc.lastChangedOn = now;
      if (dto?.reviewRemarks) {
        doc.reviewRemarks = dto.reviewRemarks.trim();
      }

      doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
      doc.timeline.push({
        action: 'DEPT_APPROVED',
        title: 'Department Approved',
        description: `Approved by Department Approver (${doc.deptApprovedBy}). Forwarded to Store for consolidation & max capacity check.`,
        actorName: doc.deptApprovedBy || 'Department Approver',
        timestamp: now,
      });

      const saved = await doc.save();
      return this.normalizeOutput(saved);
    }

    // Approval Safety & Max Capacity Auto-Cap
    if (doc.itemId) {
      const item = await this.itemModel.findById(doc.itemId);
      if (item) {
        const currentAvail =
          typeof item.stockAvailableQuantity === 'number'
            ? item.stockAvailableQuantity
            : 0;
        const maxCap =
          typeof item.maxCapacity === 'number' && item.maxCapacity > 0
            ? item.maxCapacity
            : typeof (item as any).maxQuantity === 'number' &&
                (item as any).maxQuantity > 0
              ? (item as any).maxQuantity
              : 0;

        if (maxCap > 0) {
          if (currentAvail >= maxCap) {
            if (!dto?.overrideMaxCapacity) {
              // Stock has already reached max capacity (e.g. from returns, reversions, or other receipts)
              doc.status = 'REJECTED';
              doc.reviewRemarks = dto?.reviewRemarks
                ? `${dto.reviewRemarks} (Auto-cancelled: Current stock ${currentAvail} already meets/exceeds max capacity ${maxCap})`
                : `Auto-cancelled: Current stock (${currentAvail}) already meets or exceeds maximum capacity (${maxCap}). Indent no longer required.`;
              doc.reviewedBy = user?.name || user?.email || 'Store Approver';
              doc.reviewedById = (user?._id || user?.uid || '').toString();
              doc.reviewedAt = now;
              doc.lastChangedOn = now;
              doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
              doc.timeline.push({
                action: 'REJECTED',
                title: 'Auto-Cancelled (Max Capacity Met)',
                description: `Current available stock (${currentAvail}) already reaches max capacity (${maxCap}). Indent was cancelled to prevent overstocking.`,
                actorName: doc.reviewedBy || 'Store Approver',
                timestamp: now,
              });
              const saved = await doc.save();
              return this.normalizeOutput(saved);
            } else {
              // Explicit Go Ahead override authorized
              doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
              doc.timeline.push({
                action: 'MAX_CAPACITY_OVERRIDDEN',
                title: 'Max Capacity Overridden (Go Ahead)',
                description: `Store Approver explicitly authorized Go Ahead override exceeding max capacity (${maxCap}). Current stock: ${currentAvail}.`,
                actorName: user?.name || user?.email || 'Store Approver',
                timestamp: now,
              });
            }
          }

          const requestedQty = Number(doc.indentQty ?? doc.requestedQty ?? 0);
          if (currentAvail + requestedQty > maxCap) {
            if (!dto?.overrideMaxCapacity) {
              // Auto-cap the approved quantity to fill only up to max capacity!
              const cappedQty = maxCap - currentAvail;
              const oldQty = requestedQty;
              doc.indentQty = cappedQty;
              doc.requestedQty = cappedQty;
              if (dto?.creditQty) {
                dto.creditQty = Math.min(dto.creditQty, cappedQty);
              }
              doc.reviewRemarks = dto?.reviewRemarks
                ? `${dto.reviewRemarks} (Auto-capped from ${oldQty} to ${cappedQty} to stay within max capacity ${maxCap})`
                : `Approved with Auto-Cap: Quantity adjusted from ${oldQty} to ${cappedQty} ${doc.unitOfMeasure || 'units'} to not exceed maximum capacity (${maxCap}).`;

              doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
              doc.timeline.push({
                action: 'QTY_AUTO_CAPPED',
                title: 'Approved with Auto-Cap',
                description: `Quantity auto-capped from ${oldQty} to ${cappedQty} to stay within maximum capacity (${maxCap}).`,
                actorName: user?.name || user?.email || 'Store Approver',
                timestamp: now,
              });
            } else {
              // Explicit Go Ahead override authorized
              doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
              doc.timeline.push({
                action: 'MAX_CAPACITY_OVERRIDDEN',
                title: 'Max Capacity Overridden (Go Ahead)',
                description: `Store Approver explicitly authorized Go Ahead override approving full requested quantity (${requestedQty}) exceeding max capacity (${maxCap}).`,
                actorName: user?.name || user?.email || 'Store Approver',
                timestamp: now,
              });
            }
          }
        }
      }
    }

    doc.status = 'APPROVED';
    doc.reviewedBy = user?.name || user?.email || 'Store Approver';
    doc.reviewedById = (user?._id || user?.uid || '').toString();
    doc.reviewedAt = now;
    doc.lastChangedOn = now;
    if (dto?.reviewRemarks) {
      doc.reviewRemarks = dto.reviewRemarks.trim();
    }

    doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
    doc.timeline.push({
      action: 'APPROVED',
      title: 'Indent Approved',
      description: dto?.reviewRemarks
        ? dto.reviewRemarks.trim()
        : 'Approved for warehouse receiving',
      actorName: user?.name || user?.email || 'Store Approver',
      timestamp: now,
    });

    // Option B: Direct stock credit upon approval if requested
    if (dto?.directStockIn) {
      await this.performDirectStockCredit(doc, dto, user);
    }

    const saved = await doc.save();
    return this.normalizeOutput(saved);
  }

  /**
   * Step 2.5: Consolidated Store Department Approval.
   * Store Manager approves selected indents grouped by item with optional quantity adjustments (e.g. reducing auto-refill).
   * Validates that total selected quantity does not exceed max capacity + 5% buffer.
   */
  async consolidatedStoreApprove(dto: ConsolidatedStoreApproveDto, user: any) {
    if (!dto.items || !Array.isArray(dto.items) || dto.items.length === 0) {
      throw new BadRequestException('No indents provided for store approval');
    }

    const now = new Date();
    const approvedDocs: any[] = [];
    const indentIds = dto.items.map((i) => i.indentId);

    // Fetch all targeted indents
    const docs = await this.indentModel.find({ _id: { $in: indentIds } });
    if (docs.length === 0) {
      throw new NotFoundException('None of the requested indents were found');
    }

    // Group items by itemId to validate total capacity
    const itemGroups = new Map<string, Array<{ doc: any; approvedQty: number; remarks?: string }>>();
    for (const itemDto of dto.items) {
      const doc = docs.find((d: any) => (d?._id || '').toString() === itemDto.indentId);
      if (!doc) continue;
      const itemIdStr = doc.itemId ? doc.itemId.toString() : 'UNKNOWN';
      if (!itemGroups.has(itemIdStr)) {
        itemGroups.set(itemIdStr, []);
      }
      itemGroups.get(itemIdStr)!.push({
        doc,
        approvedQty: Number(itemDto.approvedQty),
        remarks: itemDto.remarks,
      });
    }

    // Capacity validation per item
    for (const [itemIdStr, group] of itemGroups.entries()) {
      if (itemIdStr !== 'UNKNOWN') {
        const item = await this.itemModel.findById(itemIdStr);
        if (item) {
          const maxCap =
            typeof item.maxCapacity === 'number' && item.maxCapacity > 0
              ? item.maxCapacity
              : 0;

          if (maxCap > 0) {
            const currentStock = Number(item.stockAvailableQuantity) || 0;
            const totalApprovedQty = group.reduce((sum, g) => sum + g.approvedQty, 0);
            const maxAllowed = maxCap * 1.05; // 5% buffer allowed as requested by manager

            if (currentStock + totalApprovedQty > maxAllowed) {
              if (!dto.overrideMaxCapacity) {
                throw new BadRequestException(
                  `Cannot approve indents for "${item.itemName || item.itemCode}": Total selected quantity (${totalApprovedQty}) plus current stock (${currentStock}) exceeds maximum allowable quantity with buffer of ${maxAllowed.toFixed(1)} ${item.unit || 'units'} (Max: ${maxCap}). Please adjust the quantities or use Go Ahead to authorize exceeding max limit.`,
                );
              }
            }
          }
        }
      }
    }

    // Save approvals
    for (const [itemIdStr, group] of itemGroups.entries()) {
      for (const entry of group) {
        const { doc, approvedQty, remarks } = entry;
        const oldQty = Number(doc.indentQty ?? doc.requestedQty ?? 0);
        const qtyChanged = oldQty !== approvedQty;

        if (qtyChanged) {
          doc.originalIndentQty = doc.originalIndentQty || oldQty;
          doc.indentQty = approvedQty;
          doc.requestedQty = approvedQty;
        }

        doc.status = 'APPROVED';
        doc.storeApprovedAt = now;
        doc.storeApprovedBy = user?.name || user?.email || 'Store Approver';
        doc.storeApprovedById = (user?._id || user?.uid || '').toString();
        doc.reviewedAt = now;
        doc.reviewedBy = doc.storeApprovedBy;
        doc.reviewedById = doc.storeApprovedById;
        doc.lastChangedOn = now;

        if (remarks) {
          doc.reviewRemarks = remarks;
        }

        doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
        if (qtyChanged) {
          doc.timeline.push({
            action: 'QTY_ADJUSTED',
            title: 'Store Capacity Adjustment',
            description: `Store Incharge adjusted quantity from ${oldQty} to ${approvedQty} to maintain warehouse maximum capacity limit.`,
            actorName: doc.storeApprovedBy || 'Store Approver',
            timestamp: now,
          });
        }

        if (dto.overrideMaxCapacity) {
          doc.timeline.push({
            action: 'MAX_CAPACITY_OVERRIDDEN',
            title: 'Max Capacity Overridden (Go Ahead)',
            description: `Store Incharge explicitly authorized Go Ahead override exceeding maximum warehouse capacity.`,
            actorName: doc.storeApprovedBy || 'Store Approver',
            timestamp: now,
          });
        }

        doc.timeline.push({
          action: 'APPROVED',
          title: 'Store Approved (Consolidated)',
          description: `Consolidated & approved by Store Incharge (${doc.storeApprovedBy}). Available for GRN receiving & putaway.`,
          actorName: doc.storeApprovedBy || 'Store Approver',
          timestamp: now,
        });

        const saved = await doc.save();
        approvedDocs.push(this.normalizeOutput(saved));
      }
    }

    return {
      success: true,
      message: `Successfully consolidated and approved ${approvedDocs.length} indents. Items are now ready for GRN receipt.`,
      count: approvedDocs.length,
      data: approvedDocs,
    };
  }

  /**
   * Retrieves indents waiting for Store Incharge consolidation & approval.
   * Supports both Indent-Wise (Hierarchical Requisitions) and Item-Wise aggregations.
   */
  async getPendingStoreConsolidation(search?: string, groupBy?: string) {
    const filter: any = {
      status: { $in: ['PENDING', 'DEPT_APPROVED'] },
      stockCredited: { $ne: true },
    };

    const activePending = await this.indentModel
      .find(filter)
      .sort({ createdAt: 1 })
      .lean()
      .exec();

    // Collect all group keys (groupIndentNumber or indentNumber)
    const groupKeySet = new Set<string>();
    for (const doc of activePending) {
      const key = (doc as any).groupIndentNumber || doc.indentNumber;
      if (key) groupKeySet.add(key);
    }

    // Query all sibling items for these active groups so partially approved indents show both approved & pending items
    const allGroupDocs: any[] = groupKeySet.size > 0
      ? await this.indentModel
          .find({
            $or: [
              { groupIndentNumber: { $in: Array.from(groupKeySet) } },
              { indentNumber: { $in: Array.from(groupKeySet) } },
            ],
            stockCredited: { $ne: true },
            status: { $ne: 'REJECTED' },
          })
          .sort({ createdAt: 1, lineNumber: 1 })
          .lean()
          .exec()
      : [];

    // Fetch all item masters in a single batch query for maximum performance (O(1) lookups)
    const itemIds = Array.from(new Set(allGroupDocs.map((d: any) => d.itemId).filter(Boolean)));
    const itemMasters = itemIds.length > 0
      ? await this.itemModel.find({ _id: { $in: itemIds } }).lean().exec()
      : [];
    const itemMasterMap = new Map<string, any>(itemMasters.map((it: any) => [it._id.toString(), it]));

    // 1. Build Indent-Wise Grouping
    const indentGroupMap = new Map<string, any>();
    for (const doc of allGroupDocs) {
      const groupKey = doc.groupIndentNumber || doc.indentNumber || doc._id.toString();
      if (!indentGroupMap.has(groupKey)) {
        indentGroupMap.set(groupKey, {
          groupIndentNumber: groupKey,
          indentNumber: doc.indentNumber || groupKey,
          department: doc.department || 'Store Refill',
          requestedBy: doc.requestedBy || 'Store User',
          requesterRole: doc.requesterRole || 'Staff',
          isAutoRefill: !!doc.isAutoRefill,
          createdAt: doc.createdOn || doc.createdAt,
          items: [],
        });
      }

      const itemMaster = itemMasterMap.get(String(doc.itemId));
      const currentStock = Number(itemMaster?.stockAvailableQuantity) || Number(doc.currentAvailableQty) || 0;
      const maxCapacity = Number(itemMaster?.maxCapacity) || 0;
      const maxAllowedBuffer = maxCapacity > 0 ? Number((maxCapacity * 1.05).toFixed(1)) : 0;
      const requestedQty = Number(doc.indentQty ?? doc.requestedQty ?? 0);

      indentGroupMap.get(groupKey).items.push({
        ...this.normalizeOutput(doc),
        itemCode: itemMaster?.itemCode || doc.itemCode || '',
        itemName: itemMaster?.itemName || doc.itemName || doc.itemDescription || '',
        unit: itemMaster?.unit || doc.unitOfMeasure || doc.unit || 'units',
        currentStock,
        maxCapacity,
        maxAllowedBuffer,
        exceedsMax: maxCapacity > 0 && (currentStock + requestedQty) > maxCapacity,
        exceedsBuffer: maxCapacity > 0 && (currentStock + requestedQty) > maxAllowedBuffer,
        isApproved: doc.status === 'APPROVED',
      });
    }

    const indentWise = Array.from(indentGroupMap.values()).map((group: any) => {
      const totalItems = group.items.length;
      const approvedItemsCount = group.items.filter((i: any) => i.isApproved).length;
      const pendingItemsCount = totalItems - approvedItemsCount;
      const isFullyApproved = totalItems > 0 && approvedItemsCount === totalItems;
      const totalRequestedQty = group.items.reduce(
        (sum: number, i: any) => sum + (Number(i.indentQty ?? i.requestedQty) || 0),
        0,
      );
      const hasCapacityWarning = group.items.some((i: any) => i.exceedsBuffer);

      return {
        ...group,
        totalItems,
        approvedItemsCount,
        pendingItemsCount,
        isFullyApproved,
        totalRequestedQty,
        hasCapacityWarning,
        status: isFullyApproved ? 'APPROVED' : approvedItemsCount > 0 ? 'PARTIALLY_APPROVED' : 'PENDING',
      };
    });

    // 2. Build Item-Wise Grouping
    const itemMap = new Map<string, { item: any; indents: any[] }>();
    for (const doc of allGroupDocs) {
      const itemIdStr = String(doc.itemId);
      if (!itemMap.has(itemIdStr)) {
        const itemMaster = itemMasterMap.get(itemIdStr);
        itemMap.set(itemIdStr, {
          item: itemMaster || {
            _id: doc.itemId,
            itemName: doc.itemName || doc.itemDescription || 'Unknown Item',
            itemCode: doc.itemCode || '',
            unit: doc.unitOfMeasure || doc.unit || 'units',
            stockAvailableQuantity: doc.currentAvailableQty || 0,
            maxCapacity: 0,
          },
          indents: [],
        });
      }
      itemMap.get(itemIdStr)!.indents.push(this.normalizeOutput(doc));
    }

    const itemWise = Array.from(itemMap.values()).map(({ item, indents }) => {
      const currentStock = Number(item.stockAvailableQuantity) || 0;
      const maxCapacity = Number(item.maxCapacity) || 0;
      const maxAllowedBuffer = maxCapacity > 0 ? Number((maxCapacity * 1.05).toFixed(1)) : 0;
      const totalIndentQty = indents.reduce(
        (sum, i) => sum + (Number(i.indentQty ?? i.requestedQty) || 0),
        0,
      );

      return {
        itemId: item._id,
        itemName: item.itemName || indents[0]?.itemDescription || '',
        itemCode: item.itemCode || indents[0]?.itemCode || '',
        unit: item.unit || indents[0]?.unitOfMeasure || 'units',
        currentStock,
        maxCapacity,
        maxAllowedBuffer,
        totalIndentQty,
        exceedsMax: maxCapacity > 0 && (currentStock + totalIndentQty) > maxCapacity,
        exceedsBuffer: maxCapacity > 0 && (currentStock + totalIndentQty) > maxAllowedBuffer,
        indents,
      };
    });

    // Search filtering
    let filteredIndentWise = indentWise;
    let filteredItemWise = itemWise;
    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      filteredIndentWise = indentWise.filter((grp: any) =>
        (grp.groupIndentNumber || '').toLowerCase().includes(q) ||
        (grp.indentNumber || '').toLowerCase().includes(q) ||
        (grp.requestedBy || '').toLowerCase().includes(q) ||
        (grp.department || '').toLowerCase().includes(q) ||
        grp.items.some((it: any) =>
          (it.itemName || '').toLowerCase().includes(q) ||
          (it.itemCode || '').toLowerCase().includes(q)
        )
      );

      filteredItemWise = itemWise.filter((it: any) =>
        (it.itemName || '').toLowerCase().includes(q) ||
        (it.itemCode || '').toLowerCase().includes(q)
      );
    }

    // Support caller-requested single grouping or unified payload
    if (groupBy === 'item') {
      return filteredItemWise;
    }
    if (groupBy === 'indent') {
      return filteredIndentWise;
    }

    return {
      indentWise: filteredIndentWise,
      itemWise: filteredItemWise,
      summary: {
        totalIndents: filteredIndentWise.length,
        totalPendingItems: filteredIndentWise.reduce((sum: number, g: any) => sum + g.pendingItemsCount, 0),
      },
    };
  }

  /**
   * Approves a single indent item individually.
   * If all items belonging to this indent requisition become approved, the entire indent is automatically marked approved!
   */
  async approveIndentItem(id: string, dto: ApproveIndentItemDto, user: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent item not found');
    }
    if (doc.status === 'REJECTED') {
      throw new BadRequestException('Cannot approve a rejected indent item');
    }
    if (doc.status === 'APPROVED') {
      return {
        success: true,
        message: 'This item is already approved',
        data: this.normalizeOutput(doc),
        indentFullyApproved: false,
      };
    }

    const now = new Date();
    const approvedQty = Number(dto?.approvedQty ?? doc.indentQty ?? doc.requestedQty ?? 0);
    if (approvedQty <= 0) {
      throw new BadRequestException('Approved quantity must be greater than zero');
    }

    // Capacity validation
    if (doc.itemId) {
      const item = await this.itemModel.findById(doc.itemId);
      if (item) {
        const maxCap = typeof item.maxCapacity === 'number' && item.maxCapacity > 0 ? item.maxCapacity : 0;
        if (maxCap > 0) {
          const currentStock = Number(item.stockAvailableQuantity) || 0;
          const maxAllowed = maxCap * 1.05; // 5% buffer
          if (currentStock + approvedQty > maxAllowed) {
            if (!dto?.overrideMaxCapacity) {
              throw new BadRequestException(
                `Cannot approve item "${item.itemName || item.itemCode}": Current stock (${currentStock}) + Approved qty (${approvedQty}) exceeds maximum allowable quantity with buffer of ${maxAllowed.toFixed(1)} ${item.unit || 'units'} (Max: ${maxCap}). Use Go Ahead to override.`,
              );
            }
          }
        }
      }
    }

    const oldQty = Number(doc.indentQty ?? doc.requestedQty ?? 0);
    const qtyChanged = oldQty !== approvedQty;
    if (qtyChanged) {
      doc.originalIndentQty = doc.originalIndentQty || oldQty;
      doc.indentQty = approvedQty;
      doc.requestedQty = approvedQty;
    }

    doc.status = 'APPROVED';
    doc.storeApprovedAt = now;
    doc.storeApprovedBy = user?.name || user?.email || 'Store Approver';
    doc.storeApprovedById = (user?._id || user?.uid || '').toString();
    doc.reviewedAt = now;
    doc.reviewedBy = doc.storeApprovedBy;
    doc.reviewedById = doc.storeApprovedById;
    doc.lastChangedOn = now;

    if (dto?.remarks) {
      doc.reviewRemarks = dto.remarks.trim();
    }

    doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
    if (qtyChanged) {
      doc.timeline.push({
        action: 'QTY_ADJUSTED',
        title: 'Store Capacity Adjustment',
        description: `Quantity adjusted from ${oldQty} to ${approvedQty} by Store Incharge.`,
        actorName: doc.storeApprovedBy || 'Store Approver',
        timestamp: now,
      });
    }
    if (dto?.overrideMaxCapacity) {
      doc.timeline.push({
        action: 'MAX_CAPACITY_OVERRIDDEN',
        title: 'Max Capacity Overridden (Go Ahead)',
        description: `Store Incharge explicitly authorized Go Ahead override exceeding maximum warehouse capacity.`,
        actorName: doc.storeApprovedBy || 'Store Approver',
        timestamp: now,
      });
    }
    doc.timeline.push({
      action: 'APPROVED',
      title: 'Store Approved (Item)',
      description: dto?.remarks || `Item approved by Store Incharge (${doc.storeApprovedBy}). Available for GRN receiving.`,
      actorName: doc.storeApprovedBy || 'Store Approver',
      timestamp: now,
    });

    const saved = await doc.save();

    // Check sibling items for automatic whole-indent approval
    const groupKey = saved.groupIndentNumber || saved.indentNumber;
    let allSiblingsApproved = false;
    let siblingTotal = 1;
    let siblingApproved = 1;

    if (groupKey) {
      const siblings = await this.indentModel.find({
        $or: [
          { groupIndentNumber: groupKey },
          { indentNumber: groupKey },
        ],
        status: { $ne: 'REJECTED' },
        stockCredited: { $ne: true },
      });

      siblingTotal = siblings.length;
      siblingApproved = siblings.filter((s: any) => s.status === 'APPROVED').length;
      allSiblingsApproved = siblingTotal > 0 && siblingApproved === siblingTotal;

      if (allSiblingsApproved) {
        for (const sib of siblings) {
          sib.timeline = Array.isArray(sib.timeline) ? sib.timeline : [];
          sib.timeline.push({
            action: 'INDENT_FULLY_APPROVED',
            title: 'Indent Automatically Fully Approved',
            description: `All ${siblingTotal} item(s) in Indent ${groupKey} are now approved. Requisition is ready for complete GRN receiving.`,
            actorName: doc.storeApprovedBy || 'Store Approver',
            timestamp: now,
          });
          await sib.save();
        }
      }
    }

    return {
      success: true,
      message: allSiblingsApproved
        ? `Item approved. All ${siblingTotal} items in Indent ${groupKey} are now approved! Indent is automatically fully approved.`
        : `Item approved successfully (${siblingApproved}/${siblingTotal} items approved in Indent ${groupKey || saved.indentNumber}).`,
      indentFullyApproved: allSiblingsApproved,
      groupIndentNumber: groupKey || saved.indentNumber,
      approvedCount: siblingApproved,
      totalCount: siblingTotal,
      data: this.normalizeOutput(saved),
    };
  }

  /**
   * Approves the whole indent requisition and all its pending line items in one operation.
   */
  async approveWholeIndent(indentKey: string, dto: ApproveWholeIndentDto, user: any) {
    if (!indentKey || !indentKey.trim()) {
      throw new BadRequestException('Indent number or group key is required');
    }
    const cleanKey = indentKey.trim();

    const docs = await this.indentModel.find({
      $or: [
        { groupIndentNumber: cleanKey },
        { indentNumber: cleanKey },
      ],
      status: { $ne: 'REJECTED' },
      stockCredited: { $ne: true },
    });

    if (!docs || docs.length === 0) {
      throw new NotFoundException(`No active indent found for "${cleanKey}"`);
    }

    const now = new Date();
    const approverName = user?.name || user?.email || 'Store Approver';
    const approverId = (user?._id || user?.uid || '').toString();

    const pendingDocs = docs.filter((d: any) => d.status !== 'APPROVED');
    if (pendingDocs.length === 0) {
      return {
        success: true,
        message: `All items in Indent ${cleanKey} are already approved.`,
        count: docs.length,
        indentNumber: cleanKey,
      };
    }

    // Validate capacities for all pending items
    for (const doc of pendingDocs) {
      if (doc.itemId) {
        const item = await this.itemModel.findById(doc.itemId);
        if (item) {
          const maxCap = typeof item.maxCapacity === 'number' && item.maxCapacity > 0 ? item.maxCapacity : 0;
          if (maxCap > 0) {
            const currentStock = Number(item.stockAvailableQuantity) || 0;
            const requestedQty = Number(doc.indentQty ?? doc.requestedQty ?? 0);
            const maxAllowed = maxCap * 1.05;
            if (currentStock + requestedQty > maxAllowed) {
              if (!dto?.overrideMaxCapacity) {
                throw new BadRequestException(
                  `Cannot approve indent: Item "${item.itemName || item.itemCode}" (Current Stock: ${currentStock}, Indent: ${requestedQty}) exceeds maximum allowable quantity with buffer of ${maxAllowed.toFixed(1)} ${item.unit || 'units'} (Max: ${maxCap}). Use Go Ahead to override.`,
                );
              }
            }
          }
        }
      }
    }

    // Approve all pending docs
    for (const doc of pendingDocs) {
      doc.status = 'APPROVED';
      doc.storeApprovedAt = now;
      doc.storeApprovedBy = approverName;
      doc.storeApprovedById = approverId;
      doc.reviewedAt = now;
      doc.reviewedBy = approverName;
      doc.reviewedById = approverId;
      doc.lastChangedOn = now;

      if (dto?.remarks) {
        doc.reviewRemarks = dto.remarks.trim();
      }

      doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
      if (dto?.overrideMaxCapacity) {
        doc.timeline.push({
          action: 'MAX_CAPACITY_OVERRIDDEN',
          title: 'Max Capacity Overridden (Go Ahead)',
          description: `Store Incharge authorized Go Ahead override exceeding maximum capacity during whole-indent approval.`,
          actorName: approverName,
          timestamp: now,
        });
      }
      doc.timeline.push({
        action: 'APPROVED',
        title: 'Indent Approved (Whole Indent)',
        description: dto?.remarks || `Whole indent ${cleanKey} approved by Store Incharge (${approverName}). All items ready for GRN receipt.`,
        actorName: approverName,
        timestamp: now,
      });

      await doc.save();
    }

    return {
      success: true,
      message: `Indent ${cleanKey} and all ${pendingDocs.length} pending items have been approved! Indent is fully approved.`,
      count: docs.length,
      newlyApprovedCount: pendingDocs.length,
      indentNumber: cleanKey,
    };
  }

  /**
   * Rejects the whole indent requisition and all its pending items.
   */
  async rejectWholeIndent(indentKey: string, dto: { remarks?: string }, user: any) {
    if (!indentKey || !indentKey.trim()) {
      throw new BadRequestException('Indent number or group key is required');
    }
    const cleanKey = indentKey.trim();

    const docs = await this.indentModel.find({
      $or: [
        { groupIndentNumber: cleanKey },
        { indentNumber: cleanKey },
      ],
      stockCredited: { $ne: true },
      status: { $in: ['PENDING', 'DEPT_APPROVED'] },
    });

    if (!docs || docs.length === 0) {
      throw new NotFoundException(`No pending indents found for "${cleanKey}" to reject`);
    }

    const now = new Date();
    const rejectorName = user?.name || user?.email || 'Store Approver';
    const rejectorId = (user?._id || user?.uid || '').toString();

    for (const doc of docs) {
      doc.status = 'REJECTED';
      doc.reviewedBy = rejectorName;
      doc.reviewedById = rejectorId;
      doc.reviewedAt = now;
      doc.lastChangedOn = now;
      if (dto?.remarks) {
        doc.reviewRemarks = dto.remarks.trim();
      }

      doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
      doc.timeline.push({
        action: 'REJECTED',
        title: 'Indent Rejected (Whole Indent)',
        description: dto?.remarks || `Whole indent ${cleanKey} was rejected by Store Approver (${rejectorName}).`,
        actorName: rejectorName,
        timestamp: now,
      });

      await doc.save();
    }

    return {
      success: true,
      message: `Indent ${cleanKey} and all ${docs.length} pending items have been rejected.`,
      count: docs.length,
      indentNumber: cleanKey,
    };
  }

  /**
   * Directly credits physical stock into a rack for an indent (works for both pending and already-approved indents).
   */
  async creditStock(id: string, dto: ReviewIndentRaiseDto, user: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    if (doc.status === 'REJECTED') {
      throw new BadRequestException('Cannot credit stock for a rejected indent');
    }
    if (doc.stockCredited) {
      throw new BadRequestException('Stock has already been credited for this indent');
    }

    const now = new Date();
    if (doc.status === 'PENDING') {
      doc.status = 'APPROVED';
      doc.reviewedBy = user?.name || user?.email || 'Store Approver';
      doc.reviewedById = (user?._id || user?.uid || '').toString();
      doc.reviewedAt = now;
    }
    if (dto?.reviewRemarks) {
      doc.reviewRemarks = dto.reviewRemarks.trim();
    }
    doc.lastChangedOn = now;

    await this.performDirectStockCredit(doc, dto, user);

    const saved = await doc.save();
    return this.normalizeOutput(saved);
  }

  /**
   * Helper to perform physical stock credit into rack via StoreNewItemService.
   */
  private async performDirectStockCredit(
    doc: any,
    dto: ReviewIndentRaiseDto,
    user: any,
  ) {
    const rawQty = dto.creditQty ?? doc.indentQty ?? doc.requestedQty;
    const qty = Number(rawQty);
    if (!rawQty || isNaN(qty) || qty <= 0) {
      throw new BadRequestException('Credit quantity must be greater than 0');
    }

    // 1. Determine target rack
    let targetRackId = dto.rackId ? String(dto.rackId).trim() : '';
    let targetRack: any = null;

    if (targetRackId && Types.ObjectId.isValid(targetRackId)) {
      targetRack = await this.rackModel.findById(targetRackId);
    }

    if (!targetRack) {
      // Find rack already associated with this item
      const itemRack = await this.itemRackQtyModel
        .findOne({ itemId: String(doc.itemId) })
        .sort({ updatedAt: -1 });

      if (itemRack?.rackId && Types.ObjectId.isValid(String(itemRack.rackId))) {
        targetRack = await this.rackModel.findById(itemRack.rackId);
      }
    }

    if (!targetRack) {
      // Fallback: Find any active rack in the store
      targetRack = await this.rackModel.findOne({
        isActive: { $ne: false },
        isScrap: { $ne: true },
      });
      if (!targetRack) {
        targetRack = await this.rackModel.findOne();
      }
    }

    if (!targetRack) {
      throw new BadRequestException(
        'No warehouse rack available to credit stock into. Please create or configure a rack first.',
      );
    }

    targetRackId = String(targetRack._id);
    const rackCode = targetRack.code || targetRack.rackName || 'RACK';

    // 2. Operator identity
    let operatorId = (user?._id || user?.uid || '').toString();
    if (!Types.ObjectId.isValid(operatorId)) {
      operatorId = '650000000000000000000001';
    }

    // 3. Delegate to StoreNewItemService receiveItem (updates rack, item available, and creates StoreReceive)
    const receiveResult = await this.storeItemService.receiveItem({
      itemId: String(doc.itemId),
      rackId: targetRackId,
      qty,
      receivedBy: operatorId,
      remark: `Indent Stock In: ${doc.indentNumber || doc.requestNo || 'Direct Credit'}${dto.reviewRemarks ? ' - ' + dto.reviewRemarks : ''}`,
      recNo: doc.indentNumber || doc.requestNo,
      requestId: `IND-CREDIT-${doc._id}`,
    });

    // 4. Mark doc
    doc.stockCredited = true;
    doc.stockCreditedAt = new Date();
    doc.creditedRackId = targetRackId;
    doc.creditedRackCode = rackCode;
    doc.creditedQty = qty;
    doc.receiveDocId = receiveResult?.id || '';

    // 5. Automatic Issue Creation & Stock Reservation for Requester Indents
    const reqId = (doc.requesterId || '').toString();
    const isHumanRequester =
      reqId &&
      reqId !== 'system' &&
      Types.ObjectId.isValid(reqId) &&
      !doc.requestedBy?.toUpperCase().includes('AUTO REFILL');

    if (isHumanRequester && this.issueService) {
      try {
        const autoReason =
          doc.reason?.trim() ||
          `Shortage fulfilled from Indent ${doc.indentNumber || doc.requestNo}`;
        const autoRemark = `Auto-generated Issue for Requester Indent ${doc.indentNumber || doc.requestNo} (Qty: ${qty})`;

        const issueResult = await this.issueService.createDraftBulk({
          createdBy: reqId,
          reason: autoReason,
          remark: autoRemark,
          lines: [
            {
              itemId: String(doc.itemId),
              requestedQty: qty,
            },
          ],
        });
        console.log(
          `[AutoIssue] Successfully auto-created Issue Request ${issueResult?.issNo} for Requester ${reqId} from Indent ${doc.indentNumber}`,
        );

        if (issueResult?._id) {
          doc.sourceIssueId = String(issueResult._id);
          doc.timeline.push({
            action: 'AUTO_ISSUED',
            title: `Auto-Reserved for Requester (${issueResult.issNo})`,
            description: `Auto-reserved ${qty} units for ${doc.requestedBy || 'requester'} under Issue Request ${issueResult.issNo}`,
            actorName: 'System Automation',
            timestamp: new Date(),
          });
          await doc.save();
        }

        if (this.notificationService) {
          await this.notificationService.notifyRequesterStockArrivedAndAutoIssued({
            userId: reqId,
            itemId: String(doc.itemId),
            itemName: doc.itemName || doc.itemDescription || 'Requested Item',
            itemCode: doc.itemCode || '',
            unit: doc.unitOfMeasure || '',
            qty,
            indentNo: doc.indentNumber || doc.requestNo || '',
            issueNo: issueResult?.issNo,
          });
        }
      } catch (err: any) {
        console.error(
          `[AutoIssue] Failed to auto-create Issue Request for Requester ${reqId}:`,
          err?.message || err,
        );
        doc.timeline.push({
          action: 'AUTO_ISSUE_FAILED',
          title: 'Auto-Reservation Failed',
          description: `Auto-reservation failed for requester: ${err?.message || err}`,
          actorName: 'System Automation',
          timestamp: new Date(),
        });
        await doc.save().catch(() => {});
      }
    }
  }

  /**
   * Fulfills an approved indent when the item is physically received via the Store Receive screen.
   * Marks the indent as credited, links the receive receipt, auto-creates an Issue Request for the requester,
   * and sends 2 notifications to the requester.
   */
  async fulfillIndentFromReceive(params: {
    indentId: string;
    receivingDocId: string;
    rackId: string;
    qty: number;
    operatorId: string;
    remark?: string;
    autoIssue?: boolean;
  }): Promise<any> {
    if (!params.indentId || !Types.ObjectId.isValid(params.indentId)) {
      return null;
    }

    const doc = await this.indentModel.findById(params.indentId);
    if (!doc) return null;

    let targetRackCode = '';
    if (params.rackId && Types.ObjectId.isValid(params.rackId)) {
      const rack = await this.rackModel.findById(params.rackId);
      if (rack) {
        targetRackCode = rack.code || rack.rackName || 'RACK';
      }
    }

    const now = new Date();
    doc.status = 'APPROVED';
    doc.stockCredited = true;
    doc.stockCreditedAt = now;
    doc.creditedRackId = params.rackId;
    doc.creditedRackCode = targetRackCode;
    doc.creditedQty = params.qty;
    doc.receiveDocId = params.receivingDocId;
    doc.lastChangedOn = now;
    doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
    doc.timeline.push({
      action: 'RECEIVED',
      title: 'Stock Received & Putaway',
      description: `Received ${params.qty} into rack ${targetRackCode}${params.remark ? ' - ' + params.remark : ''}`,
      actorName: params.operatorId || 'Store Operator',
      timestamp: now,
    });
    await doc.save();

    // Intelligent origin-based autoIssue resolution:
    // 1. If explicitly passed (true/false), honor the caller's parameter.
    // 2. Otherwise auto-detect:
    //    - ISSUE_SHORTAGE -> true (auto-reserve for waiting requester)
    //    - STORE_REFILL / AUTO_REFILL -> false (direct to available store inventory)
    const effectiveIndentType = doc.indentType || (
      (doc.requestedBy || '').toUpperCase().includes('AUTO REFILL') ||
      (doc.requestedBy || '').toUpperCase().includes('SYSTEM')
        ? 'AUTO_REFILL'
        : (doc.reason || '').toUpperCase().includes('SHORTAGE')
          ? 'ISSUE_SHORTAGE'
          : 'STORE_REFILL'
    );
    // Strict server-side enforcement:
    // General store refills & auto refills CANNOT be converted to issues; they MUST credit available stock.
    // Issue shortages strictly route to auto-issue (reserve for requester).
    const shouldAutoIssue = effectiveIndentType === 'ISSUE_SHORTAGE'
      ? (params.autoIssue !== undefined ? params.autoIssue === true : true)
      : false;

    const reqId = (doc.requesterId || '').toString();
    const isHumanRequester =
      shouldAutoIssue &&
      reqId &&
      reqId !== 'system' &&
      Types.ObjectId.isValid(reqId) &&
      !doc.requestedBy?.toUpperCase().includes('AUTO REFILL');

    let issueResult: any = null;
    if (isHumanRequester && this.issueService) {
      try {
        const autoReason =
          doc.reason?.trim() ||
          `Shortage fulfilled from Indent ${doc.indentNumber || doc.requestNo}`;
        const autoRemark = `Auto-generated Issue for Requester Indent ${doc.indentNumber || doc.requestNo} (Qty: ${params.qty})`;

        issueResult = await this.issueService.createDraftBulk({
          createdBy: reqId,
          reason: autoReason,
          remark: autoRemark,
          lines: [
            {
              itemId: String(doc.itemId),
              requestedQty: params.qty,
            },
          ],
        });
        console.log(
          `[AutoIssue] Successfully auto-created Issue Request ${issueResult?.issNo} for Requester ${reqId} from Received Indent ${doc.indentNumber}`,
        );

        if (issueResult?._id) {
          doc.sourceIssueId = String(issueResult._id);
          doc.timeline.push({
            action: 'AUTO_ISSUED',
            title: `Auto-Reserved for Requester (${issueResult.issNo})`,
            description: `Auto-reserved ${params.qty} units for ${doc.requestedBy || 'requester'} under Issue Request ${issueResult.issNo}`,
            actorName: 'System Automation',
            timestamp: new Date(),
          });
          await doc.save();
        }
      } catch (err: any) {
        console.error(
          `[AutoIssue] Failed to auto-create Issue Request for Requester ${reqId}:`,
          err?.message || err,
        );
        doc.timeline.push({
          action: 'AUTO_ISSUE_FAILED',
          title: 'Auto-Reservation Failed',
          description: `Auto-reservation failed for requester: ${err?.message || err}`,
          actorName: 'System Automation',
          timestamp: new Date(),
        });
        await doc.save().catch(() => {});
      }
    }

    // Send 2 notifications to requester
    if (isHumanRequester && this.notificationService) {
      await this.notificationService.notifyRequesterStockArrivedAndAutoIssued({
        userId: reqId,
        itemId: String(doc.itemId),
        itemName: doc.itemName || doc.itemDescription || 'Requested Item',
        itemCode: doc.itemCode || '',
        unit: doc.unitOfMeasure || '',
        qty: params.qty,
        indentNo: doc.indentNumber || doc.requestNo || '',
        issueNo: issueResult?.issNo,
      });
    }

    return this.normalizeOutput(doc);
  }

  /**
   * Rejects an indent request.
   * DATA SAFETY: Rejection strictly does NOT modify physical inventory.
   */
  async reject(id: string, dto: ReviewIndentRaiseDto, user: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    if (doc.status !== 'PENDING' && doc.status !== 'DEPT_APPROVED') {
      throw new BadRequestException(
        `Cannot reject indent. Current status is already ${doc.status}`,
      );
    }

    const now = new Date();
    doc.status = 'REJECTED';
    doc.reviewedBy = user?.name || user?.email || 'Store Approver';
    doc.reviewedById = (user?._id || user?.uid || '').toString();
    doc.reviewedAt = now;
    doc.lastChangedOn = now;
    if (dto?.reviewRemarks) {
      doc.reviewRemarks = dto.reviewRemarks.trim();
    }

    doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
    doc.timeline.push({
      action: 'REJECTED',
      title: 'Indent Rejected',
      description: dto?.reviewRemarks
        ? dto.reviewRemarks.trim()
        : 'Indent request was rejected by approver',
      actorName: user?.name || user?.email || 'Store Approver',
      timestamp: now,
    });

    // DATA SAFETY: Rejection does NOT modify inventory.
    const saved = await doc.save();
    return this.normalizeOutput(saved);
  }

  /**
   * Updates requested quantity on a PENDING indent.
   * Also updates defaultRefillQuantity on the item master to maintain desired auto-refill sizing.
   */
  async updateQuantity(id: string, dto: UpdateIndentQtyDto, user?: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    const isPending = doc.status === 'PENDING';
    const isApprovedUncredited =
      doc.status === 'APPROVED' && !doc.stockCredited;

    if (!isPending && !isApprovedUncredited) {
      throw new BadRequestException(
        `Cannot edit indent quantity. Current status is ${doc.status}${doc.stockCredited ? ' (stock already credited into warehouse)' : ''}.`,
      );
    }

    const rawQty = dto.indentQty ?? dto.requestedQty;
    const newQty = Number(rawQty);
    if (!rawQty || isNaN(newQty) || newQty < 1) {
      throw new BadRequestException(
        'Indent quantity must be a positive number of at least 1',
      );
    }

    // Capacity validation against item maxCapacity
    if (doc.itemId) {
      const item = await this.itemModel.findById(doc.itemId);
      if (item) {
        const maxCap =
          typeof item.maxCapacity === 'number' && item.maxCapacity > 0
            ? item.maxCapacity
            : typeof (item as any).maxQuantity === 'number' &&
                (item as any).maxQuantity > 0
              ? (item as any).maxQuantity
              : 0;
        const avail =
          typeof item.stockAvailableQuantity === 'number'
            ? item.stockAvailableQuantity
            : 0;

        if (maxCap > 0 && avail + newQty > maxCap) {
          const maxAllowed = Math.max(0, maxCap - avail);
          throw new BadRequestException(
            `Cannot increase indent quantity to ${newQty}. Available stock is ${avail} and maximum capacity is ${maxCap}. You can only indent up to ${maxAllowed} units.`,
          );
        }
      }
    }

    const oldQty = doc.indentQty || doc.requestedQty || 0;
    doc.indentQty = newQty;
    doc.requestedQty = newQty;
    doc.lastChangedOn = new Date();

    if (dto.reason && dto.reason.trim()) {
      doc.reason = dto.reason.trim();
    }

    doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];

    if (isApprovedUncredited) {
      // Approach 1: Move back to PENDING so the approver re-authorizes the amended quantity
      doc.status = 'PENDING';
      doc.timeline.push({
        action: 'AMENDMENT_REQUESTED',
        title: 'Quantity Increase Requested (Re-approval Required)',
        description: `Approved quantity amended from ${oldQty} to ${newQty} ${doc.unitOfMeasure || 'units'}${dto.reason ? ' (' + dto.reason.trim() + ')' : ''}. Requires re-approval.`,
        actorName: user?.name || user?.email || 'Store User',
        timestamp: new Date(),
      });
    } else {
      doc.timeline.push({
        action: 'QTY_EDITED',
        title: 'Quantity Adjusted',
        description: `Quantity adjusted from ${oldQty} to ${newQty} ${doc.unitOfMeasure || 'units'}${dto.reason ? ' (' + dto.reason.trim() + ')' : ''}`,
        actorName: user?.name || user?.email || 'Store User',
        timestamp: new Date(),
      });
    }

    const saved = await doc.save();

    // Persist this quantity as defaultRefillQuantity on the item for all future auto-refills
    if (doc.itemId) {
      await this.itemModel.findByIdAndUpdate(doc.itemId, {
        $set: { defaultRefillQuantity: newQty },
      });
    }

    return this.normalizeOutput(saved);
  }

  /**
   * Deletes an uncredited indent request from the system.
   */
  async delete(id: string, user?: any) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid indent request ID');
    }
    const doc = await this.indentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Indent record not found');
    }
    if (doc.stockCredited) {
      throw new BadRequestException(
        'Cannot delete an indent that has already been credited to stock.',
      );
    }
    await this.indentModel.findByIdAndDelete(id);
    return {
      success: true,
      id,
      msg: `Indent ${doc.indentNumber || doc.requestNo} deleted successfully`,
    };
  }

  async pushTimelineEvent(
    indentId: string,
    event: { action: string; title: string; description: string; actorName?: string },
  ): Promise<void> {
    if (!indentId || !Types.ObjectId.isValid(indentId)) return;
    try {
      const doc = await this.indentModel.findById(indentId);
      if (!doc) return;
      doc.timeline = Array.isArray(doc.timeline) ? doc.timeline : [];
      doc.timeline.push({
        action: event.action,
        title: event.title,
        description: event.description,
        actorName: event.actorName || 'System',
        timestamp: new Date(),
      });
      await doc.save();
    } catch (err) {
      console.error('[StockRefillRequestService] pushTimelineEvent error:', err);
    }
  }


  /**
   * Normalizes document output to guarantee both reference fields and legacy fields
   * are populated, whether reading existing historical records or newly created indents.
   */
  private normalizeOutput(rawDoc: any): any {
    const obj = rawDoc.toObject ? rawDoc.toObject() : { ...rawDoc };
    const id = (obj._id || obj.id || '').toString();
    const indentNum = obj.indentNumber || obj.requestNo || '';
    const desc = obj.itemDescription || obj.itemName || '';
    const unitVal = obj.unitOfMeasure || obj.unit || '';
    const qtyVal = obj.indentQty ?? obj.requestedQty ?? 0;

    return {
      ...obj,
      _id: obj._id,
      id,
      indentNumber: indentNum,
      requestNo: indentNum,
      itemDescription: desc,
      itemName: obj.itemName || desc,
      unitOfMeasure: unitVal,
      unit: unitVal,
      indentQty: qtyVal,
      requestedQty: qtyVal,
      make: obj.make ?? '',
      techSpec: obj.techSpec ?? '',
      lineNumber: obj.lineNumber ?? 1,
      createdOn: obj.createdOn || obj.createdAt || new Date(),
      lastChangedOn: obj.lastChangedOn || obj.updatedAt || new Date(),
      preReqQty: obj.preReqQty ?? 0,
      preqQty: obj.preqQty ?? 0,
      balanceQty: obj.balanceQty ?? obj.currentAvailableQty ?? 0,
      documentCategory: obj.documentCategory || 'ITEM_MASTER',
      company: obj.company || 'STORE',
      costCenter: obj.costCenter || 'MAIN_STORE',
      documentDate: obj.documentDate || obj.createdOn || obj.createdAt || new Date(),
      documentType: obj.documentType || 'INDENT',
      requestedBy: obj.requestedBy || '',
      hsnCode: obj.hsnCode ?? '',
      indentType: obj.indentType || (
        (obj.requestedBy || '').toUpperCase().includes('AUTO REFILL') ||
        (obj.requestedBy || '').toUpperCase().includes('SYSTEM')
          ? 'AUTO_REFILL'
          : (obj.reason || '').toUpperCase().includes('SHORTAGE')
            ? 'ISSUE_SHORTAGE'
            : 'STORE_REFILL'
      ),
      sourceIssueId: obj.sourceIssueId || '',
      status: (obj.status || 'PENDING').toUpperCase(),
      originalIndentQty: obj.originalIndentQty ?? null,
      deptApprovedAt: obj.deptApprovedAt || null,
      deptApprovedBy: obj.deptApprovedBy || '',
      storeApprovedAt: obj.storeApprovedAt || null,
      storeApprovedBy: obj.storeApprovedBy || '',
      stockCredited: obj.stockCredited === true,
      stockCreditedAt: obj.stockCreditedAt || null,
      creditedRackId: obj.creditedRackId || '',
      creditedRackCode: obj.creditedRackCode || '',
      creditedQty: obj.creditedQty ?? null,
      receiveDocId: obj.receiveDocId || '',
      timeline:
        Array.isArray(obj.timeline) && obj.timeline.length > 0
          ? obj.timeline
          : [
              {
                action: 'CREATED',
                title: 'Indent Raised',
                description: obj.reason
                  ? `Requested: ${obj.reason}`
                  : `Indent requisition created for ${qtyVal} ${unitVal}`,
                actorName: obj.requestedBy || 'Store User',
                timestamp: obj.createdOn || obj.createdAt || new Date(),
              },
              ...(obj.reviewedAt || (obj.status && obj.status.toUpperCase() === 'APPROVED')
                ? [
                    {
                      action: 'APPROVED',
                      title: 'Indent Approved',
                      description:
                        obj.reviewRemarks ||
                        'Approved for warehouse receiving',
                      actorName: obj.reviewedBy || 'Store Approver',
                      timestamp:
                        obj.reviewedAt || obj.lastChangedOn || new Date(),
                    },
                  ]
                : []),
              ...(obj.status && obj.status.toUpperCase() === 'REJECTED'
                ? [
                    {
                      action: 'REJECTED',
                      title: 'Indent Rejected',
                      description:
                        obj.reviewRemarks || 'Indent request rejected',
                      actorName: obj.reviewedBy || 'Store Approver',
                      timestamp:
                        obj.reviewedAt || obj.lastChangedOn || new Date(),
                    },
                  ]
                : []),
              ...(obj.stockCredited || obj.receiveDocId
                ? [
                    {
                      action: 'RECEIVED',
                      title: 'Stock Received & Putaway',
                      description: `Received ${obj.creditedQty || qtyVal} into rack ${obj.creditedRackCode || 'Rack'}`,
                      actorName: 'Store Operator',
                      timestamp:
                        obj.stockCreditedAt || obj.lastChangedOn || new Date(),
                    },
                  ]
                : []),
            ],
    };
  }

  // =========================================================================
  // Indent Drafts (Unsubmitted Holding Area with Real-Time Stock)
  // =========================================================================

  /**
   * Retrieves all unsubmitted indent-ready items for the specified user,
   * enriched with authoritative real-time inventory levels from StoreNewItem.
   */
  async getDrafts(userId: string) {
    if (!userId) return [];

    const draft = await this.indentDraftModel
      .findOne({ userId })
      .lean()
      .exec();

    if (!draft || !draft.items || draft.items.length === 0) {
      return [];
    }

    const itemIds = draft.items
      .map((i) => i.itemId)
      .filter((id) => Types.ObjectId.isValid(id))
      .map((id) => new Types.ObjectId(id));

    const masterDocs = await this.itemModel
      .find({ _id: { $in: itemIds } })
      .select(
        'itemName itemCode unit imageUrl stockAvailableQuantity totalStockQuantity minStockQuantity maxCapacity maxQuantity',
      )
      .lean()
      .exec();

    const masterMap = new Map<string, any>(
      masterDocs.map((doc: any) => [String(doc._id), doc]),
    );

    return draft.items.map((i) => {
      const m = masterMap.get(i.itemId);
      const avail =
        typeof m?.stockAvailableQuantity === 'number'
          ? m.stockAvailableQuantity
          : 0;
      const total =
        typeof m?.totalStockQuantity === 'number'
          ? m.totalStockQuantity
          : 0;

      return {
        itemId: i.itemId,
        itemName: m?.itemName || i.itemName || 'Store Item',
        itemCode: m?.itemCode || i.itemCode || '',
        unit: m?.unit || i.unit || 'PCS',
        imageUrl: m?.imageUrl || i.imageUrl || '',
        quantity: i.quantity,
        reason: i.reason || '',
        addedAt: i.addedAt,
        realTimeAvailableQty: avail,
        realTimeTotalQty: total,
        minStockQuantity: m?.minStockQuantity ?? 0,
        isRestocked: avail >= i.quantity,
      };
    });
  }

  /**
   * Adds or updates unsubmitted items in the requester's indent draft holding area.
   */
  async addDraftItems(userId: string, items: AddIndentDraftItemDto[]) {
    if (!userId || !items || items.length === 0) {
      return this.getDrafts(userId);
    }

    let draft = await this.indentDraftModel.findOne({ userId }).exec();
    if (!draft) {
      draft = new this.indentDraftModel({ userId, items: [] });
    }

    for (const it of items) {
      if (!it.itemId) continue;
      const existingIdx = draft.items.findIndex((x) => x.itemId === it.itemId);
      if (existingIdx >= 0) {
        draft.items[existingIdx].quantity += it.quantity;
        if (it.reason) draft.items[existingIdx].reason = it.reason;
        draft.items[existingIdx].addedAt = new Date();
      } else {
        (draft.items as any).push({
          itemId: it.itemId,
          itemName: it.itemName || '',
          itemCode: it.itemCode || '',
          unit: it.unit || 'PCS',
          imageUrl: it.imageUrl || '',
          quantity: it.quantity,
          reason: it.reason || '',
          indentType: it.indentType || 'STORE_REFILL',
          addedAt: new Date(),
        });
      }
    }

    await draft.save();
    return this.getDrafts(userId);
  }

  /**
   * Updates quantity or reason for a single item in the draft list.
   */
  async updateDraftItemQty(
    userId: string,
    itemId: string,
    dto: UpdateIndentDraftItemDto,
  ) {
    if (!userId || !itemId) {
      throw new BadRequestException('User ID and Item ID are required');
    }

    const draft = await this.indentDraftModel.findOne({ userId }).exec();
    if (!draft) {
      throw new NotFoundException('No draft items found for user');
    }

    const idx = draft.items.findIndex((x) => x.itemId === itemId);
    if (idx < 0) {
      throw new NotFoundException('Draft item not found');
    }

    if (dto.quantity <= 0) {
      (draft.items as any).splice(idx, 1);
    } else {
      draft.items[idx].quantity = dto.quantity;
      if (dto.reason !== undefined) {
        draft.items[idx].reason = dto.reason;
      }
      draft.items[idx].addedAt = new Date();
    }

    await draft.save();
    return this.getDrafts(userId);
  }

  /**
   * Removes a single item from the requester's draft list.
   */
  async removeDraftItem(userId: string, itemId: string) {
    if (!userId || !itemId) return [];

    const draft = await this.indentDraftModel.findOne({ userId }).exec();
    if (draft) {
      draft.items = draft.items.filter((x) => x.itemId !== itemId) as any;
      await draft.save();
    }

    return this.getDrafts(userId);
  }

  /**
   * Clears all unsubmitted draft items for the user.
   */
  async clearDrafts(userId: string) {
    if (!userId) return [];
    await this.indentDraftModel.deleteOne({ userId }).exec();
    return [];
  }

  /**
   * Combines multiple indent-ready draft items and submits them as ONE single Indent Requisition.
   * Status moves to PENDING (Approval Pending).
   */
  async submitCombined(
    userId: string,
    dto: SubmitCombinedIndentDto,
    user: any,
  ) {
    if (!userId) {
      throw new BadRequestException('Missing user authentication');
    }

    const draft = await this.indentDraftModel.findOne({ userId }).exec();
    if (!draft || !draft.items || draft.items.length === 0) {
      throw new BadRequestException(
        'No indent-ready draft items available to submit',
      );
    }

    const toSubmit =
      dto.itemIds && dto.itemIds.length > 0
        ? draft.items.filter((i) => dto.itemIds!.includes(i.itemId))
        : [...draft.items];

    if (toSubmit.length === 0) {
      throw new BadRequestException(
        'None of the specified items were found in your draft list',
      );
    }

    // Generate single master indent reference number for this combined requisition
    const baseIndentNumber = await this.generateIndentNumber();

    const itemIds = toSubmit
      .map((i) => i.itemId)
      .filter((id) => Types.ObjectId.isValid(id))
      .map((id) => new Types.ObjectId(id));

    const masters = await this.itemModel.find({ _id: { $in: itemIds } }).exec();
    const masterMap = new Map<string, any>(masters.map((m: any) => [String(m._id), m]));

    const requestedBy = user?.name || user?.email || 'Store User';
    const requesterId = (user?._id || user?.uid || userId).toString();
    const now = new Date();

    const createdDocs: IndentRaiseDocument[] = [];

    try {
      for (let i = 0; i < toSubmit.length; i++) {
        const draftItem = toSubmit[i];
        const m = masterMap.get(draftItem.itemId);
        const lineNumber = i + 1;
        const indentNumber =
          i === 0 ? baseIndentNumber : await this.generateIndentNumber();

        const avail =
          typeof m?.stockAvailableQuantity === 'number'
            ? m.stockAvailableQuantity
            : 0;
        const total =
          typeof m?.totalStockQuantity === 'number' ? m.totalStockQuantity : 0;

        const maxQty =
          typeof m?.maxCapacity === 'number' && m.maxCapacity > 0
            ? m.maxCapacity
            : typeof (m as any)?.maxQuantity === 'number' && (m as any).maxQuantity > 0
              ? (m as any).maxQuantity
              : 0;

        if (maxQty > 0) {
          const currentStock = Math.max(0, avail);
          if (currentStock >= maxQty) {
            throw new BadRequestException(
              `Cannot submit combined indent: Material "${m?.itemName || draftItem.itemName}" has reached its maximum quantity of ${maxQty} (Current stock: ${currentStock}).`,
            );
          }
          if (currentStock + draftItem.quantity > maxQty) {
            throw new BadRequestException(
              `Cannot submit combined indent: Material "${m?.itemName || draftItem.itemName}" requested quantity (${draftItem.quantity}) exceeds maximum quantity of ${maxQty}. Current stock: ${currentStock}. Maximum allowable indent is ${maxQty - currentStock}.`,
            );
          }
        }

        const itemCode = (m?.itemCode || draftItem.itemCode || '').trim();
        const itemName = (m?.itemName || draftItem.itemName || '').trim();
        const itemDesc = (m?.description || itemName).trim() || itemName;
        const unit = (m?.unit || draftItem.unit || 'PCS').trim();

        const doc = new this.indentModel({
          indentType: ((draftItem as any).indentType || '').trim() || 'STORE_REFILL',
          indentNumber,
          groupIndentNumber: baseIndentNumber,
          itemCode,
          itemDescription: itemDesc,
          make: '',
          techSpec: '',
          unitOfMeasure: unit,
          lineNumber,
          createdOn: now,
          lastChangedOn: now,
          indentQty: draftItem.quantity,
          preReqQty: 0,
          preqQty: 0,
          balanceQty: avail,
          documentCategory: 'ITEM_MASTER',
          company: dto.company || 'STORE',
          costCenter: dto.costCenter || 'MAIN_STORE',
          documentDate: now,
          documentType: 'INDENT',
          requestedBy,
          hsnCode: '',

          itemId: (m?._id ||
            (Types.ObjectId.isValid(draftItem.itemId)
              ? new Types.ObjectId(draftItem.itemId)
              : new Types.ObjectId())) as any,
          requesterId,
          status: this.storeCartService?.isIndentApprovalRequired() ? 'PENDING' : 'APPROVED',
          reason:
            (draftItem.reason || dto.reason || '').trim() ||
            'Requester Indent (Stock Shortfall)',
          currentAvailableQty: avail,
          currentTotalQty: total,
          timeline: [
            {
              action: 'CREATED',
              title: 'Indent Raised',
              description: this.storeCartService?.isIndentApprovalRequired()
                ? 'Submitted in combined requisition for approval'
                : 'Auto-approved in combined requisition (Indent approval disabled)',
              actorName: requestedBy,
              timestamp: now,
            },
            ...(this.storeCartService?.isIndentApprovalRequired()
              ? []
              : [
                  {
                    action: 'APPROVED',
                    title: 'Auto-Approved',
                    description: 'Directly available in Receive section',
                    actorName: 'System Settings',
                    timestamp: now,
                  },
                ]),
          ],

          // Legacy compatibility mirrors
          requestNo: indentNumber,
          itemName,
          unit,
          requestedQty: draftItem.quantity,
        });

        const saved = await doc.save();
        createdDocs.push(saved);
      }

      // Remove submitted items from draft holding list
      const submittedIds = new Set(toSubmit.map((i) => i.itemId));
      draft.items = draft.items.filter((i) => !submittedIds.has(i.itemId)) as any;
      await draft.save();

      return {
        groupIndentNumber: baseIndentNumber,
        submittedCount: createdDocs.length,
        indents: createdDocs.map((d) => this.normalizeOutput(d)),
      };
    } catch (err: any) {
      console.error('[SubmitCombined] Error submitting combined indents:', err);
      throw err;
    }
  }
}

// Backward compatibility alias for existing module injection and imports
export { IndentRaiseService as StockRefillRequestService };
