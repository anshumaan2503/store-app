import {
  BadRequestException,
  forwardRef,
  Inject,
  Injectable,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types, ClientSession } from 'mongoose';
import { Rack } from '../../locations/rack/entities/rack.schema';
import { StoreCategory } from '../store-category/entities/store-category.schema';
import { StoreNewItem } from '../store-item/entities/store-item.schema';
import { ItemIssueDocument } from './entities/store-item-issue.schema';
import {
  IssueOneLineDto,
  IssueBulkDto,
  ReturnLineDto,
  ReturnBulkDto,
} from './dto/create-store-item-issue.dto';
import { StockTrack } from '../store-item/entities/stock-track.schema';
import {
  ItemRackQty,
  ItemRackQtyDocument,
} from '../../locations/rack/entities/item-rack-qty.schema';
import { UserService } from 'src/features/user/user.service';
import { Bag, BagDocument } from 'src/features/bags/entities/bag.schema';
import {
  Machine,
  MachineDocument,
} from 'src/features/sorting-job/entities/machine.schema';
import { StoreCartService } from '../store-cart/store-cart.service';
import { IndentRaiseService } from 'src/features/stock-refill-request/stock-refill-request.service';

// ✅ Adjust these imports/paths to your project
// If you have class-based schema:
/// import { StockTrack } from '../stock-track/entities/stock-stock-track.schema';
type IssuedItemUI = {
  id: string;
  itemCode: string;
  itemName: string;
  categoryId: string;
  netIssued: number;
  issueNos: string[]; // ✅ issNo list here
};
type CategoryWithIssuedItems = {
  categoryId: string;
  code: string;
  name: string;
  parentId: string[];
  isMachine: boolean;
  isbag: boolean;
  isNormalItem: boolean;
  items: IssuedItemUI[]; // ✅ keep items:list only
};

type StockTrackType =
  | 'CREATE'
  | 'APPROVED'
  | 'APPROVAL_REVERTED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'ISSUE'
  | 'RETURN'
  | 'SCRAP'
  | 'CLOSED';

@Injectable()
export class IssueService {
  constructor(
    @InjectModel('ItemIssue', 'store')
    private readonly issueModel: Model<ItemIssueDocument>,

    @InjectModel('StoreNewItem', 'store')
    private readonly itemModel: Model<StoreNewItem>,

    @InjectModel('StoreCategory', 'store')
    private readonly catModel: Model<StoreCategory>,

    @InjectModel('Rack', 'store')
    private readonly rackModel: Model<Rack>,

    // ✅ Stock Track model (change model name if yours differs)
    @InjectModel('StockTrack', 'store')
    private readonly stockTrackModel: Model<StockTrack>,

    @InjectModel(ItemRackQty.name, 'store')
    private readonly itemRackQtyModel: Model<ItemRackQtyDocument>,

    @InjectModel(Bag.name, 'store')
    private readonly bagModel: Model<BagDocument>,

    @InjectModel(Machine.name, 'store')
    private readonly machineModel: Model<MachineDocument>,

    private readonly userService: UserService,
    @Inject(forwardRef(() => StoreCartService))
    private readonly storeCartService: StoreCartService,
    @Inject(forwardRef(() => IndentRaiseService))
    private readonly indentService: IndentRaiseService,
  ) {}

  async revertExpiredDrafts(): Promise<number> {
    const timeoutMs = this.storeCartService?.getRequestTimeoutMs();
    if (timeoutMs === null) {
      // Disabled by Super Admin: Zero DB queries!
      return 0;
    }

    const now = new Date();
    const threshold = new Date(Date.now() - timeoutMs);

    const expiredIssues = await this.issueModel.find({
      status: 'DRAFT',
      $or: [
        { expiresAt: { $ne: null, $lt: now } },
        { createdAt: { $lt: threshold } },
      ],
    });

    if (!expiredIssues.length) return 0;

    let revertedCount = 0;
    const days = Math.max(1, Math.round(timeoutMs / (24 * 60 * 60 * 1000)));

    for (const issue of expiredIssues) {
      const lines = issue.lines || [];
      for (const line of lines) {
        const itemId = String(line.itemId || '').trim();
        const requested = this.num(line.requestedQty, 0);
        const approved = this.num(line.approvedQty, 0);
        const rejected = this.num(line.approvedRejectQty, 0);
        const unapprovedQty = Math.max(0, requested - (approved + rejected));

        if (unapprovedQty > 0 && Types.ObjectId.isValid(itemId)) {
          const itemDoc = await this.itemModel.findById(this.oid(itemId));
          if (itemDoc) {
            const curRequested = Number((itemDoc as any).stockRequestedQuantity || 0);
            const curAvail = Number((itemDoc as any).stockAvailableQuantity || 0);
            (itemDoc as any).stockRequestedQuantity = Math.max(0, curRequested - unapprovedQty);
            (itemDoc as any).stockAvailableQuantity = curAvail + unapprovedQty;
            await itemDoc.save();
            this.indentService
              .checkAndCancelAutoIndentIfStockRestored(
                String(itemDoc._id),
                (itemDoc as any).stockAvailableQuantity,
                `Auto-cancelled: Expired requisition ${issue.issNo} was reverted and stock restored.`,
              )
              .catch(() => {});
          }
        }
      }

      issue.status = 'EXPIRED';
      const prevRemark = String(issue.remark || '').trim();
      issue.remark = prevRemark
        ? `${prevRemark} [Auto-reverted: ${days} days expired without approval]`
        : `[Auto-reverted: ${days} days expired without approval]`;
      issue.markModified('lines');
      await issue.save();

      await this.track({
        type: 'CLOSED',
        qty: 0,
        operatedBy: 'SYSTEM',
        issue,
        note: `Auto-reverted draft ${issue.issNo}: ${days} days expired without approval`,
      });

      revertedCount++;
    }

    return revertedCount;
  }

  async revertMonthEndUnclaimedIssues(): Promise<number> {
    const isEnabled = this.storeCartService?.isMonthEndRevertEnabled();
    if (!isEnabled) {
      // Disabled by Super Admin: Zero DB queries!
      return 0;
    }

    const now = new Date();
    // Start of the current month (e.g. 1st of month at 00:00:00.000).
    // Any issue approved in a previous month that remains uncollected is overdue.
    const startOfCurrentMonth = new Date(
      now.getFullYear(),
      now.getMonth(),
      1,
      0,
      0,
      0,
      0,
    );

    const overdueIssues = await this.issueModel.find({
      status: 'APPROVED',
      $or: [
        { approvedAt: { $ne: null, $lt: startOfCurrentMonth } },
        { approvedAt: null, createdAt: { $lt: startOfCurrentMonth } },
      ],
    });

    if (!overdueIssues.length) return 0;

    let revertedCount = 0;

    for (const issue of overdueIssues) {
      const lines = issue.lines || [];

      for (const line of lines as any[]) {
        const approvedQty = this.num(line.approvedQty, 0);
        const issuedQty = this.num(line.issuedQty, 0);
        const unissuedQty = Math.max(0, approvedQty - issuedQty);

        if (
          unissuedQty > 0 &&
          line.itemId &&
          Types.ObjectId.isValid(String(line.itemId))
        ) {
          const storeItem = await this.itemModel.findById(this.oid(line.itemId));
          if (storeItem) {
            const curAvail = Number((storeItem as any).stockAvailableQuantity || 0);
            const curIssue = Number((storeItem as any).stockIssueQuantity || 0);

            // Revert uncollected quantity back to available stock
            (storeItem as any).stockIssueQuantity = Math.max(
              0,
              curIssue - unissuedQty,
            );
            (storeItem as any).stockAvailableQuantity = curAvail + unissuedQty;

            await storeItem.save();
            this.indentService
              .checkAndCancelAutoIndentIfStockRestored(
                String(storeItem._id),
                (storeItem as any).stockAvailableQuantity,
                `Auto-cancelled: Requisition ${issue.issNo} unclaimed at month-end and stock restored.`,
              )
              .catch(() => {});
          }

          // Reset approved quantity to what was actually picked up
          line.approvedQty = issuedQty;
        }
      }

      const totalIssuedSoFar = (lines as any[]).reduce(
        (sum: number, l: any) => sum + this.num(l.issuedQty, 0),
        0,
      );

      issue.status = totalIssuedSoFar > 0 ? 'CLOSED' : 'EXPIRED';
      const prevRemark = String(issue.remark || '').trim();
      issue.remark = prevRemark
        ? `${prevRemark} [Auto-reverted: Unclaimed ready-for-issue items reverted to available stock at month end]`
        : `[Auto-reverted: Unclaimed ready-for-issue items reverted to available stock at month end]`;
      issue.markModified('lines');
      await issue.save();

      await this.track({
        type: 'CLOSED',
        qty: 0,
        operatedBy: 'SYSTEM',
        issue,
        note: `Auto-reverted unclaimed ready-for-issue ${issue.issNo}: Month ended without pickup`,
      });

      revertedCount++;
    }

    return revertedCount;
  }

  private n(v: any, fb = 0) {
    const x = Number(v);
    return Number.isFinite(x) ? x : fb;
  }

  private oid(id: any) {
    const s = String(id || '').trim();
    if (!Types.ObjectId.isValid(s))
      throw new BadRequestException('Invalid ObjectId');
    return new Types.ObjectId(s);
  }

  private asOid(v: any) {
    if (!v) return null;
    if (v instanceof Types.ObjectId) return v;
    return this.oid(v);
  }

  private findLine(issue: ItemIssueDocument, itemId: string) {
    const idx = (issue.lines || []).findIndex(
      (l: any) => String(l.itemId) === String(itemId),
    );
    if (idx < 0) throw new BadRequestException('Line not found for itemId');
    return { line: issue.lines[idx] as any, idx };
  }

  private num(v: any, fallback = 0) {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }

  private clamp(n: number, min: number, max: number) {
    return Math.max(min, Math.min(max, n));
  }

  private computeCloseStatus(issue: any) {
    const lines = issue.lines || [];
    const anyApproved = lines.some((l: any) => this.n(l.approvedQty, 0) > 0);
    const allIssuedAgainstApproved = lines.every((l: any) => {
      const ap = this.n(l.approvedQty, 0);
      const isd = this.n(l.issuedQty, 0);
      return isd >= ap;
    });
    if (anyApproved && allIssuedAgainstApproved) return 'CLOSED';
    return 'APPROVED';
  }

  /* -------------------------------------------------------
     ✅ STOCK TRACK HELPERS
     ------------------------------------------------------- */

  private async track(params: {
    type: StockTrackType;
    qty: number; // recommended signed: ISSUE negative, RETURN positive, SCRAP negative
    operatedBy: string; // userId
    issue?: any; // issue doc
    item?: any; // store item doc (optional)
    itemId?: any;
    issueId?: any;
    refNo?: string;
    note?: string;
    rackId?: string;
  }) {
    const operatedBy = String(params.operatedBy || '').trim();
    if (!Types.ObjectId.isValid(operatedBy)) return;

    const issue = params.issue || null;
    const item = params.item || null;

    const issueId = params.issueId
      ? this.asOid(params.issueId)
      : issue?._id
        ? this.asOid(issue._id)
        : null;

    const itemId = params.itemId
      ? this.asOid(params.itemId)
      : item?._id
        ? this.asOid(item._id)
        : null;

    let rackId: any = null;
    if (params.rackId) {
      rackId = this.asOid(params.rackId);
    } else if (item?.rackId) {
      const rId = Array.isArray(item.rackId) ? item.rackId[0] : item.rackId;
      if (rId && Types.ObjectId.isValid(String(rId))) {
        rackId = this.asOid(rId);
      }
    }

    const refNo = params.refNo ?? (issue?.issNo ? String(issue.issNo) : '');

    // category/rack from item if present
    const categoryId = item?.categoryId ? this.asOid(item.categoryId) : null;
    // const rackId = item?.rackId ? this.asOid(item.rackId) : null;

    // Keep payload flexible — if your schema requires fields, enforce here.
    await this.stockTrackModel.create({
      type: params.type,
      qty: Number(params.qty || 0),
      operatedBy: this.oid(operatedBy),

      refNo,
      note: params.note ?? '',

      itemId,
      categoryId,
      rackId,

      issueId,
      receivingId: null,
    });
  }

  private async checkDivisionAuthorization(
    issuedBy: string,
    createdBy: string,
  ) {
    const approveUser = await this.userService.findById(issuedBy);
    const createUser = await this.userService.findById(createdBy);

    const a = (approveUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    const b = (createUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    const setA = new Set<string>(a);
    const hasCommonDivision =
      approveUser?.isSuperAdmin ||
      createUser?.isSuperAdmin ||
      a.length === 0 ||
      b.length === 0 ||
      b.some((id) => setA.has(id));

    if (!hasCommonDivision) throw new BadRequestException('Senior not found');
  }

  private async trackCloseIfChanged(
    prevStatus: string,
    issue: any,
    operatedBy: string,
  ) {
    const nextStatus = String(issue?.status || '').toUpperCase();
    if (prevStatus !== 'CLOSED' && nextStatus === 'CLOSED') {
      await this.track({
        type: 'CLOSED',
        qty: 0,
        operatedBy,
        issue,
        note: `Issue auto-closed (issNo=${issue?.issNo || ''})`,
      });
    }
  }

  /* -------------------------------------------------------
     (optional) if you ever use this, it now tracks ISSUE too
     ------------------------------------------------------- */
  private async deductStockOrThrow(itemId: string, qty: number) {
    const item = await this.itemModel.findById(this.oid(itemId));
    if (!item) throw new BadRequestException('Store item not found');

    const avail = this.n((item as any).stockAvailableQuantity, 0);
    if (qty > avail) {
      throw new BadRequestException(
        `Insufficient stock. Available=${avail}, requested=${qty}`,
      );
    }

    (item as any).stockAvailableQuantity = avail - qty;
    (item as any).stockIssueQuantity =
      this.n((item as any).stockIssueQuantity, 0) + qty;
    (item as any).stockissueCompleted =
      this.n((item as any).stockissueCompleted, 0) + qty;

    await item.save();

    await this.indentService
      .checkAndTriggerAutoIndent(
        String(item._id),
        (item as any).stockAvailableQuantity,
      )
      .catch((err) =>
        console.error('Auto indent trigger error in deductStockOrThrow:', err),
      );

    // ✅ Track (ISSUE is negative movement)
    await this.track({
      type: 'ISSUE',
      qty: -qty,
      operatedBy: '', // if you store, else pass real userId from caller
      item,
      itemId: item._id,
      note: `deductStockOrThrow qty=${qty}`,
    });

    return {
      rackId: String((item as any).rackId),
      rackName: String((item as any).rackName ?? ''),
      itemName: String((item as any).itemName ?? ''),
    };
  }

  /* ---------------- A) SOURCES FOR UI ---------------- */

  async getIssueSourcesForSelectedItem(selectedItemId: string) {
    const item = await this.itemModel.findById(this.oid(selectedItemId)).lean();
    if (!item) throw new BadRequestException('Item not found');

    // const itemNameOid = this.asOid((item as any).itemNameId);
    // if (!itemNameOid) throw new BadRequestException('Item has no itemNameId');

    const parentCategoryOid = this.asOid((item as any).categoryId);
    const parentCategoryId = parentCategoryOid ? String(parentCategoryOid) : '';

    const children = parentCategoryOid
      ? await this.catModel
          .find({ parentId: parentCategoryOid })
          .select({ name: 1, parentId: 1 })
          .lean()
      : [];

    const childIds = children.map((c: any) => String(c._id));
    const allBucketIds = [
      ...(parentCategoryId ? [parentCategoryId] : []),
      ...childIds,
    ].filter(Boolean);

    const bucketOids = allBucketIds.map((x) => this.oid(x));

    const items = await this.itemModel
      .find({
        // itemNameId: itemNameOid,
        ...(bucketOids.length ? { categoryId: { $in: bucketOids } } : {}),
      })
      .select({
        itemName: 1,
        itemNameCode: 1,
        unit: 1,
        categoryId: 1,
        rackId: 1,
        rackName: 1,
        stockAvailableQuantity: 1,
        totalStockQuantity: 1,
      })
      .lean();

    const byCat = new Map<
      string,
      {
        categoryId: string;
        categoryName: string;
        available: number;
        itemIds: string[];
      }
    >();

    if (parentCategoryId) {
      byCat.set(parentCategoryId, {
        categoryId: parentCategoryId,
        categoryName: 'Category',
        available: 0,
        itemIds: [],
      });
    }

    for (const child of children) {
      byCat.set(String(child._id), {
        categoryId: String(child._id),
        categoryName: child.name ?? '',
        available: 0,
        itemIds: [],
      });
    }

    for (const it of items) {
      const cid = (it as any).categoryId ? String((it as any).categoryId) : '';
      const av = Number((it as any).stockAvailableQuantity || 0);

      if (cid && byCat.has(cid)) {
        const b = byCat.get(cid)!;
        b.available += av;
        b.itemIds.push(String((it as any)._id));
      }

      if (parentCategoryId && byCat.has(parentCategoryId)) {
        const p = byCat.get(parentCategoryId)!;
        p.available += av;
        p.itemIds.push(String((it as any)._id));
      }
    }

    if (parentCategoryOid) {
      const parent = await this.catModel.findById(parentCategoryOid).lean();
      const p = byCat.get(parentCategoryId);
      if (p) p.categoryName = parent?.name ?? 'Category';
    }

    const resultBuckets = Array.from(byCat.values())
      .filter((b) => b.available > 0 || b.categoryId === parentCategoryId)
      .sort(
        (a, b) =>
          (a.categoryId === parentCategoryId ? 1 : 0) -
          (b.categoryId === parentCategoryId ? 1 : 0),
      );

    return {
      selectedItemId: String((item as any)._id),
      // itemNameId: String(itemNameOid),
      itemName: (item as any).itemName ?? '',
      itemNameCode: (item as any).itemNameCode ?? '',
      unit: (item as any).unit ?? '',
      parentCategoryId: parentCategoryId || null,
      buckets: resultBuckets,
    };
  }

  private async nextIssueNumber() {
    const n = Date.now().toString().slice(-6);
    return `ISS-${new Date().getFullYear()}-${n}`;
  }

  /* ---------------- CREATE DRAFT BULK ---------------- */

  async createDraftBulk(dto: any) {
    const createdBy = String(dto?.createdBy || '').trim();
    const reason = String(dto?.reason || '').trim();
    const remark = String(dto?.remark || '').trim();
    const lines = Array.isArray(dto?.lines) ? dto.lines : [];

    if (!Types.ObjectId.isValid(createdBy)) {
      throw new BadRequestException('createdBy invalid');
    }
    if (!lines.length) {
      throw new BadRequestException('lines required');
    }

    const merged = new Map<string, number>();
    for (const l of lines) {
      const itemId = String(l?.itemId || '').trim();
      const requestedQty = Number(l?.requestedQty || 0);

      if (!Types.ObjectId.isValid(itemId)) {
        throw new BadRequestException(`Invalid itemId: ${itemId}`);
      }
      if (!Number.isFinite(requestedQty) || requestedQty <= 0) {
        throw new BadRequestException(
          `requestedQty must be > 0 for itemId: ${itemId}`,
        );
      }

      merged.set(itemId, (merged.get(itemId) ?? 0) + requestedQty);
    }

    const itemIds = [...merged.keys()].map((id) => this.oid(id));

    const items = await this.itemModel
      .find({ _id: { $in: itemIds } })
      .select({ itemName: 1, unit: 1, stockAvailableQuantity: 1, stockRequestedQuantity: 1 })
      .lean();

    if (items.length !== itemIds.length) {
      const found = new Set(items.map((x: any) => String(x._id)));
      const missing = [...merged.keys()].filter((id) => !found.has(id));
      throw new BadRequestException(
        `Some items not found: ${missing.join(', ')}`,
      );
    }

    const issueLines = items.map((it: any) => {
      const id = String(it._id);
      const qty = merged.get(id)!;
      const avail = Number(it.stockAvailableQuantity || 0);

      if (qty > avail) {
        throw new BadRequestException(
          `Insufficient unreserved stock for ${it.itemName ?? id}. Requested ${qty}, available: ${avail}`,
        );
      }

      return {
        itemId: this.oid(id),
        itemName: String(it.itemName || '').trim(),
        requestedQty: qty,
        approvedQty: 0,
        issuedQty: 0,
        returnQty: 0,
        scrapQty: 0,
        unit: String(it.unit || '').trim(),
      };
    });

    const issNo = await this.nextIssueNumber();
    const timeoutMs = this.storeCartService?.getRequestTimeoutMs();
    const expiresAt = timeoutMs !== null ? new Date(Date.now() + timeoutMs) : null;

    let departmentName = '';
    let divisionName = '';
    try {
      const user = await this.userService.findById(createdBy);
      if (user) {
        departmentName = (user as any).departmentName || '';
        if (Array.isArray((user as any).divisionIds) && (user as any).divisionIds.length > 0) {
          const firstDiv = (user as any).divisionIds[0];
          divisionName =
            typeof firstDiv === 'object' && firstDiv?.divisionName
              ? String(firstDiv.divisionName).trim()
              : '';
        }
      }
    } catch (_) {}

    const issue = await this.issueModel.create({
      issNo,
      reason,
      remark,
      status: 'DRAFT',
      expiresAt,
      departmentName,
      divisionName,
      createdBy: this.oid(createdBy),
      lines: issueLines,
      allocations: [],
    });

    // Hold the requested quantity and immediately deduct available stock
    for (const [id, qty] of merged.entries()) {
      await this.itemModel.findByIdAndUpdate(this.oid(id), {
        $inc: {
          stockRequestedQuantity: qty,
          stockAvailableQuantity: -qty,
        },
      });
      this.indentService
        .checkAndTriggerAutoIndent(id, undefined, { id: createdBy })
        .catch((err) =>
          console.error('Auto indent trigger error in createDraftBulk:', err),
        );
    }

    // ✅ Track CREATE
    await this.track({
      type: 'CREATE',
      qty: 0,
      operatedBy: createdBy,
      issue,
      issueId: issue._id,
      refNo: issNo,
      note: `Draft created (bulk) lines=${issueLines.length}`,
    });

    return {
      _id: String(issue._id),
      issNo,
      linesCount: issueLines.length,
    };
  }

  /* ---------------- CREATE DRAFT FROM SELECTED ITEM ---------------- */

  async createDraftFromSelectedItem(dto: any) {
    const selectedItemId = String(dto?.itemId || '').trim();
    const requestedQty = Number(dto?.requestedQty || 0);
    const createdBy = String(dto?.createdBy || '').trim();
    const chosenSubCategoryId = String(dto?.subCategoryId || '').trim();

    if (!selectedItemId) throw new BadRequestException('itemId required');
    if (!Types.ObjectId.isValid(createdBy))
      throw new BadRequestException('createdBy invalid');
    if (!Number.isFinite(requestedQty) || requestedQty <= 0)
      throw new BadRequestException('requestedQty must be > 0');

    const sources = await this.getIssueSourcesForSelectedItem(selectedItemId);

    let bucket: any = null;

    if (chosenSubCategoryId && sources.buckets?.length) {
      bucket =
        sources.buckets.find(
          (b: any) => b.categoryId === chosenSubCategoryId && b.available > 0,
        ) ?? null;
    }

    if (!bucket) {
      bucket =
        sources.buckets.find(
          (b: any) =>
            b.categoryId !== sources.parentCategoryId && b.available > 0,
        ) ??
        sources.buckets.find(
          (b: any) =>
            b.categoryId === sources.parentCategoryId && b.available > 0,
        ) ??
        null;
    }

    if (!bucket)
      throw new BadRequestException('No stock available for this item');

    const representativeItemId = bucket.itemIds?.[0];
    if (!representativeItemId)
      throw new BadRequestException('No item mapping found in selected bucket');

    const repItem = await this.itemModel.findById(this.oid(representativeItemId)).lean();
    if (repItem) {
      const avail = Number((repItem as any).stockAvailableQuantity || 0);
      if (requestedQty > avail) {
        throw new BadRequestException(
          `Insufficient unreserved stock for ${repItem.itemName}. Requested ${requestedQty}, available: ${avail}`,
        );
      }
    }

    const issNo = await this.nextIssueNumber();
    const timeoutMs = this.storeCartService?.getRequestTimeoutMs();
    const expiresAt = timeoutMs !== null ? new Date(Date.now() + timeoutMs) : null;

    let departmentName = '';
    let divisionName = '';
    try {
      const user = await this.userService.findById(createdBy);
      if (user) {
        departmentName = (user as any).departmentName || '';
        if (Array.isArray((user as any).divisionIds) && (user as any).divisionIds.length > 0) {
          const firstDiv = (user as any).divisionIds[0];
          divisionName =
            typeof firstDiv === 'object' && firstDiv?.divisionName
              ? String(firstDiv.divisionName).trim()
              : '';
        }
      }
    } catch (_) {}

    const issue = await this.issueModel.create({
      issNo,
      reason: String(dto?.reason || '').trim(),
      remark: String(dto?.remark || '').trim(),
      status: 'DRAFT',
      expiresAt,
      departmentName,
      divisionName,
      createdBy: this.oid(createdBy),
      lines: [
        {
          itemId: this.oid(representativeItemId),
          itemName: `${sources.itemName}`.trim(),
          requestedQty,
          approvedQty: 0,
          issuedQty: 0,
          returnQty: 0,
          scrapQty: 0,
          unit: sources.unit ?? '',
        },
      ],
      allocations: [],
    });

    // Hold the requested quantity and immediately deduct available stock
    await this.itemModel.findByIdAndUpdate(this.oid(representativeItemId), {
      $inc: {
        stockRequestedQuantity: requestedQty,
        stockAvailableQuantity: -requestedQty,
      },
    });

    this.indentService
      .checkAndTriggerAutoIndent(representativeItemId, undefined, {
        id: createdBy,
      })
      .catch((err) =>
        console.error(
          'Auto indent trigger error in createDraftFromSelectedItem:',
          err,
        ),
      );

    // ✅ Track CREATE
    await this.track({
      type: 'CREATE',
      qty: 0,
      operatedBy: createdBy,
      issue,
      issueId: issue._id,
      refNo: issNo,
      note: `Draft created (selected item) requestedQty=${requestedQty}`,
    });

    return {
      _id: String(issue._id),
      issNo,
      chosenBucket: {
        categoryId: bucket.categoryId,
        categoryName: bucket.categoryName,
        available: bucket.available,
      },
    };
  }

  /* ---------------- APPROVE HEADER (single-line issues) ---------------- */

  async approveIssue(issueId: string, dto: any) {
    const approvedBy = String(dto?.approvedBy || '').trim();
    if (!Types.ObjectId.isValid(approvedBy))
      throw new BadRequestException('approvedBy invalid');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');
    // if (String(issue.status).toUpperCase() !== 'DRAFT')
    //   throw new BadRequestException('Only DRAFT can be approved');
    if (!issue.lines?.length) throw new BadRequestException('No lines');

    const line: any = issue.lines[0];
    const requestedQty = Number(line.requestedQty || 0);
    const prevApprovedHeader = this.num(line.approvedQty, 0);

    let approvedQty = Number(dto?.approvedQty ?? requestedQty);
    let approvedRejectQty = Number(dto?.approvedRejectQty ?? 0);
    if (!Number.isFinite(approvedQty) || approvedQty <= 0)
      approvedQty = requestedQty;
    if (approvedQty > requestedQty) approvedQty = requestedQty;

    const deltaApprovedHeader = approvedQty - prevApprovedHeader;
    const deltaHandledHeader = deltaApprovedHeader + approvedRejectQty;

    if (deltaHandledHeader > 0 && line.itemId) {
      const itemDoc = await this.itemModel.findById(this.oid(line.itemId));
      if (itemDoc) {
        const curAvail = Number((itemDoc as any).stockAvailableQuantity || 0);
        const curReq = Number((itemDoc as any).stockRequestedQuantity || 0);
        const curIssue = Number((itemDoc as any).stockIssueQuantity || 0);
        if (deltaApprovedHeader > 0) {
          (itemDoc as any).stockIssueQuantity = Math.max(0, curIssue + deltaApprovedHeader);
        }
        if (approvedRejectQty > 0) {
          (itemDoc as any).stockAvailableQuantity = curAvail + approvedRejectQty;
          this.indentService
            .checkAndCancelAutoIndentIfStockRestored(
              String(itemDoc._id),
              (itemDoc as any).stockAvailableQuantity,
              `Auto-cancelled: Line rejection on requisition ${issue.issNo} restored stock.`,
            )
            .catch(() => {});
        }
        (itemDoc as any).stockRequestedQuantity = Math.max(0, curReq - deltaHandledHeader);
        await itemDoc.save();

        if (deltaApprovedHeader > 0) {
          await this.indentService
            .checkAndTriggerAutoIndent(
              String(itemDoc._id),
              (itemDoc as any).stockAvailableQuantity,
              { id: approvedBy },
            )
            .catch((err) =>
              console.error('Auto indent trigger error in approveRequest:', err),
            );
        }
      }
    }

    line.approvedQty = approvedQty;
    line.approvedRejectQty = approvedRejectQty;

    issue.status = 'APPROVED';
    (issue as any).expiresAt = null;
    (issue as any).approvedBy = this.oid(approvedBy);
    (issue as any).approvedAt = new Date();

    issue.markModified('lines');
    await issue.save();

    // ✅ Track APPROVED
    await this.track({
      type: 'APPROVED',
      qty: 0,
      operatedBy: approvedBy,
      issue,
      note: `Header approved approvedQty=${approvedQty}`,
    });

    return true;
  }

  /* ---------------- APPROVE ONE LINE ---------------- */

  async approveIssueLine(issueId: string, itemIds: string, dto: any) {
    const approvedBy = String(dto?.approvedBy || '').trim();
    const itemId = String(itemIds || '').trim();
    const mode = String(dto?.mode || 'add').toLowerCase() as 'add' | 'set';
    const qty = Number(dto.approvedQty || 0);
    const reject = Number(dto.approvedRejectQty || 0);

    if (!Types.ObjectId.isValid(approvedBy)) {
      throw new BadRequestException('approvedBy invalid');
    }

    if (!Types.ObjectId.isValid(itemId)) {
      throw new BadRequestException('itemId invalid');
    }

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');
    // if (String(issue.status).toUpperCase() !== 'DRAFT')
    //   throw new BadRequestException('Only DRAFT can be approved');

    const approveUser = await this.userService.findById(approvedBy);
    const createUser = await this.userService.findById(issue.createdBy);

    const a = (approveUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    const b = (createUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    // console.log(a);
    // console.log(b);

    const setA = new Set<string>(a);

    const hasCommonDivision =
      approveUser?.isSuperAdmin ||
      createUser?.isSuperAdmin ||
      a.length === 0 ||
      b.length === 0 ||
      b.some((id) => setA.has(id)); // ✅ true if any match or if divisions not configured

    if (!hasCommonDivision) throw new BadRequestException('Senior not found');

    const storeItem = await this.itemModel.findById(this.oid(itemId));
    if (!storeItem) throw new BadRequestException('Store item not found');

    const idx = (issue.lines || []).findIndex(
      (l: any) => String(l.itemId) === itemId,
    );
    if (idx < 0) throw new BadRequestException('Line not found for itemId');

    const line: any = issue.lines[idx];
    const requested = this.num(line.requestedQty, 0);
    const prevApproved = this.num(line.approvedQty, 0);
    const prevRejected = this.num(line.approvedRejectQty, 0);
    if (!Number.isFinite(requested) || requested <= 0) {
      throw new BadRequestException('Invalid requestedQty on line');
    }

    const incomingQty = this.num(
      dto?.approvedQty,
      mode === 'add' ? 0 : prevApproved,
    );
    const approvedRejectQty = this.num(
      dto?.approvedRejectQty,
      mode === 'add' ? 0 : prevRejected,
    );

    const total = qty + reject;

    if (mode === 'add' && total <= 0) {
      throw new BadRequestException('approvedQty must be > 0 for add');
    }

    if (mode === 'add' && incomingQty < 0) {
      throw new BadRequestException('approvedQty must be > 0 for add');
    }

    if (mode === 'add' && approvedRejectQty < 0) {
      throw new BadRequestException('approvedRejectQty must be > 0 for add');
    }

    if (mode === 'set' && incomingQty < 0) {
      throw new BadRequestException('approvedQty cannot be negative');
    }

    const totalApprovedAndRejected =
      prevApproved + incomingQty + prevRejected + approvedRejectQty;
    if (requested < totalApprovedAndRejected) {
      throw new BadRequestException(
        'Requested quantity cannot be less than the sum of approved, incoming, previous rejected, and reject quantities',
      );
    }

    const nextApproved =
      mode === 'set'
        ? this.clamp(
            incomingQty,
            0,
            requested - prevRejected - approvedRejectQty,
          ) // Ensure we don't approve more than remaining after previous rejects
        : this.clamp(
            prevApproved + incomingQty,
            0,
            requested - prevRejected - approvedRejectQty,
          );

    const deltaApproved = nextApproved - prevApproved;
    const deltaRejected = approvedRejectQty;
    const deltaHandled = deltaApproved + deltaRejected;

    // Release requested hold, commit available stock, and move approved quantity to Ready for Issue
    if (deltaHandled > 0) {
      const curAvail = Number((storeItem as any).stockAvailableQuantity || 0);
      const curReq = Number((storeItem as any).stockRequestedQuantity || 0);
      const curIssue = Number((storeItem as any).stockIssueQuantity || 0);

      if (deltaApproved > 0) {
        (storeItem as any).stockIssueQuantity = Math.max(0, curIssue + deltaApproved);
      }
      if (deltaRejected > 0) {
        (storeItem as any).stockAvailableQuantity = curAvail + deltaRejected;
        this.indentService
          .checkAndCancelAutoIndentIfStockRestored(
            String(storeItem._id),
            (storeItem as any).stockAvailableQuantity,
            `Auto-cancelled: Line rejection on requisition ${issue.issNo} restored stock.`,
          )
          .catch(() => {});
      }
      (storeItem as any).stockRequestedQuantity = Math.max(0, curReq - deltaHandled);
      await storeItem.save();

      if (deltaApproved > 0) {
        await this.indentService
          .checkAndTriggerAutoIndent(
            String(storeItem._id),
            (storeItem as any).stockAvailableQuantity,
            { id: approvedBy },
          )
          .catch((err) =>
            console.error('Auto indent trigger error in approveIssueBulk:', err),
          );
      }
    }

    line.approvedQty = nextApproved;
    line.approvedRejectQty = prevRejected + approvedRejectQty;

    (issue as any).approvedBy = this.oid(approvedBy);
    (issue as any).approvedAt = new Date();

    const allHandled = (issue.lines || []).every((x: any) => {
      const rq = this.num(x.requestedQty, 0);
      const aq = this.num(x.approvedQty, 0);
      const rj = this.num(x.approvedRejectQty, 0);
      return rq > 0 && (aq + rj) >= rq;
    });
    if (allHandled) {
      const anyApproved = (issue.lines || []).some(
        (x: any) => this.num(x.approvedQty, 0) > 0,
      );
      issue.status = anyApproved ? 'APPROVED' : 'REJECTED';
      (issue as any).expiresAt = null;
    }

    issue.markModified('lines');
    await issue.save();

    // ✅ Track APPROVED
    await this.track({
      type: 'APPROVED',
      qty: 0,
      operatedBy: approvedBy,
      issue,
      note: `Approve line itemId=${itemId} approvedQty=${nextApproved} mode=${mode}`,
    });

    return {
      issueId: String(issue._id),
      issNo: (issue as any).issNo,
      // status: issue.status,
      updatedLine: {
        itemId: String(line.itemId),
        requestedQty: requested,
        approvedQty: nextApproved,
        remainingQty: Math.max(0, requested - nextApproved),
      },
    };
  }

  /* ---------------- APPROVE BULK ---------------- */

  async approveIssueBulk(issueId: string, dto: any) {
    const approvedBy = String(dto?.approvedBy || '').trim();
    if (!Types.ObjectId.isValid(approvedBy))
      throw new BadRequestException('approvedBy invalid');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');
    // if (String(issue.status).toUpperCase() !== 'DRAFT')
    //   throw new BadRequestException('Only DRAFT can be approved');

    const updates = Array.isArray(dto?.lines) ? dto.lines : [];
    if (!updates.length) throw new BadRequestException('lines required');

    const updatedLines: any[] = [];

    for (const u of updates) {
      const itemId = String(u?.itemId || '').trim();
      const mode = String(u?.mode || 'add').toLowerCase() as 'add' | 'set';
      if (!Types.ObjectId.isValid(itemId)) continue;

      const idx = (issue.lines || []).findIndex(
        (l: any) => String(l.itemId) === itemId,
      );
      if (idx < 0) continue;

      const line: any = issue.lines[idx];
      const requested = this.num(line.requestedQty, 0);
      const prevApproved = this.num(line.approvedQty, 0);
      if (requested <= 0) continue;

      const incomingQty = this.num(u?.approvedQty, 0);

      const nextApproved =
        mode === 'set'
          ? this.clamp(incomingQty, 0, requested)
          : this.clamp(prevApproved + incomingQty, 0, requested);

      const deltaApproved = nextApproved - prevApproved;
      if (deltaApproved > 0) {
        const itemDoc = await this.itemModel.findById(this.oid(itemId));
        if (itemDoc) {
          const curReq = Number((itemDoc as any).stockRequestedQuantity || 0);
          const curIssue = Number((itemDoc as any).stockIssueQuantity || 0);
          (itemDoc as any).stockRequestedQuantity = Math.max(0, curReq - deltaApproved);
          (itemDoc as any).stockIssueQuantity = Math.max(0, curIssue + deltaApproved);
          await itemDoc.save();

          await this.indentService
            .checkAndTriggerAutoIndent(
              String(itemDoc._id),
              (itemDoc as any).stockAvailableQuantity,
              { id: approvedBy },
            )
            .catch((err) =>
              console.error(
                'Auto indent trigger error in approveIssueLine:',
                err,
              ),
            );
        }
      }

      line.approvedQty = nextApproved;

      updatedLines.push({
        itemId: String(line.itemId),
        requestedQty: requested,
        approvedQty: nextApproved,
        remainingQty: Math.max(0, requested - nextApproved),
      });
    }

    (issue as any).approvedBy = this.oid(approvedBy);
    (issue as any).approvedAt = new Date();

    const allHandled = (issue.lines || []).every((x: any) => {
      const rq = this.num(x.requestedQty, 0);
      const aq = this.num(x.approvedQty, 0);
      const rj = this.num(x.approvedRejectQty, 0);
      return rq > 0 && (aq + rj) >= rq;
    });
    if (allHandled) {
      const anyApproved = (issue.lines || []).some(
        (x: any) => this.num(x.approvedQty, 0) > 0,
      );
      issue.status = anyApproved ? 'APPROVED' : 'REJECTED';
      (issue as any).expiresAt = null;
    }

    issue.markModified('lines');
    await issue.save();

    // ✅ Track APPROVED
    await this.track({
      type: 'APPROVED',
      qty: 0,
      operatedBy: approvedBy,
      issue,
      note: `Approve bulk updatedLines=${updatedLines.length}`,
    });

    return {
      issueId: String(issue._id),
      issNo: (issue as any).issNo,
      // status: issue.status,
      updatedLines,
    };
  }

  /* ---------------- REVERT APPROVAL (BEFORE PICKUP) ---------------- */

  async revertIssueApproval(issueId: string, dto: any) {
    const revertedBy = String(dto?.revertedBy || '').trim();
    const reason = String(dto?.reason || '').trim();

    if (!Types.ObjectId.isValid(revertedBy)) {
      throw new BadRequestException('revertedBy invalid');
    }

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    const revertUser = await this.userService.findById(revertedBy);
    const createUser = await this.userService.findById(issue.createdBy);

    const a = (revertUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    const b = (createUser?.divisionIds ?? [])
      .map((x) => String(x).trim().toLowerCase())
      .filter(Boolean);

    const setA = new Set<string>(a);
    const hasCommonDivision =
      revertUser?.isSuperAdmin ||
      createUser?.isSuperAdmin ||
      a.length === 0 ||
      b.length === 0 ||
      b.some((id) => setA.has(id));

    if (!hasCommonDivision) {
      throw new BadRequestException('Senior not authorized for this division');
    }

    if (!issue.lines || !issue.lines.length) {
      throw new BadRequestException('No lines found in this issue');
    }

    // Check if any lines were approved
    const totalApproved = issue.lines.reduce(
      (sum: number, l: any) => sum + Number(l.approvedQty || 0),
      0,
    );
    if (totalApproved <= 0) {
      throw new BadRequestException(
        'This request has not been approved or has 0 approved quantity.',
      );
    }

    // Check if all approved items have already been physically issued / picked up
    const totalIssued = issue.lines.reduce(
      (sum: number, l: any) => sum + Number(l.issuedQty || 0),
      0,
    );
    if (totalIssued >= totalApproved) {
      throw new BadRequestException(
        'Cannot revert approval: all approved items have already been physically issued/picked up at the store counter.',
      );
    }

    let revertedCount = 0;

    for (const line of issue.lines as any[]) {
      const approvedQty = Number(line.approvedQty || 0);
      const issuedQty = Number(line.issuedQty || 0);
      const unissuedApprovedQty = approvedQty - issuedQty;

      if (unissuedApprovedQty > 0 && line.itemId) {
        const storeItem = await this.itemModel.findById(this.oid(line.itemId));
        if (storeItem) {
          const curAvail = Number((storeItem as any).stockAvailableQuantity || 0);
          const curReq = Number((storeItem as any).stockRequestedQuantity || 0);
          const curIssue = Number((storeItem as any).stockIssueQuantity || 0);

          // 1. Deduct from Ready for Issue
          (storeItem as any).stockIssueQuantity = Math.max(
            0,
            curIssue - unissuedApprovedQty,
          );

          // 2. Return back to Requested (Back to Pending/Draft hold, stockAvailableQuantity stays deducted)
          (storeItem as any).stockRequestedQuantity = curReq + unissuedApprovedQty;

          await storeItem.save();
        }

        // Reset line approved quantity back to what was already physically issued
        line.approvedQty = issuedQty;
        revertedCount += unissuedApprovedQty;
      }
    }

    // If completely unissued (totalIssued == 0), reset status back to DRAFT
    if (totalIssued === 0) {
      issue.status = 'DRAFT';
      (issue as any).approvedBy = null;
      (issue as any).approvedAt = null;
      const timeoutMs = this.storeCartService?.getRequestTimeoutMs();
      (issue as any).expiresAt = timeoutMs !== null ? new Date(Date.now() + timeoutMs) : null;
    }

    (issue as any).revertedBy = this.oid(revertedBy);
    (issue as any).revertedAt = new Date();
    if (reason) (issue as any).revertReason = reason;

    issue.markModified('lines');
    await issue.save();

    // Track event in audit log
    try {
      await this.track({
        type: 'APPROVAL_REVERTED',
        qty: revertedCount,
        operatedBy: revertedBy,
        issue,
        note: `Approval reverted for ${revertedCount} unissued unit(s). Reason: ${reason || 'N/A'}`,
      });
    } catch (trackErr) {
      console.warn('Stock track audit warning (non-fatal):', trackErr);
    }

    return {
      issueId: String(issue._id),
      issNo: (issue as any).issNo,
      status: issue.status,
      revertedCount,
      totalIssued,
    };
  }

  /* ---------------- REJECT ENTIRE ISSUE / REQUEST ---------------- */

  async rejectIssue(issueId: string, dto: any) {
    const rejectedBy = String(dto?.rejectedBy || '').trim();
    const reason = String(dto?.reason || '').trim();

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    const totalIssued = (issue.lines || []).reduce(
      (sum: number, l: any) => sum + Number(l.issuedQty || 0),
      0,
    );
    if (totalIssued > 0) {
      throw new BadRequestException(
        'Cannot reject request because items have already been issued / picked up from stock.',
      );
    }

    if (String(issue.status).toUpperCase() === 'REJECTED') {
      throw new BadRequestException('This request is already rejected.');
    }

    let rejectedQtyTotal = 0;

    for (const line of (issue.lines as any[]) || []) {
      const requested = this.num(line.requestedQty, 0);
      const approved = this.num(line.approvedQty, 0);
      const prevRejected = this.num(line.approvedRejectQty, 0);

      // Unapproved portion held in stockRequestedQuantity
      const unapprovedRequested = Math.max(
        0,
        requested - (approved + prevRejected),
      );
      // Approved portion held in stockIssueQuantity (since totalIssued is 0)
      const approvedUnissued = approved;

      if (line.itemId && Types.ObjectId.isValid(line.itemId)) {
        const storeItem = await this.itemModel.findById(this.oid(line.itemId));
        if (storeItem) {
          const curAvail = Number(
            (storeItem as any).stockAvailableQuantity || 0,
          );
          const curReq = Number(
            (storeItem as any).stockRequestedQuantity || 0,
          );
          const curIssue = Number((storeItem as any).stockIssueQuantity || 0);

          // 1. Release requested hold and restore back to Available
          if (unapprovedRequested > 0) {
            (storeItem as any).stockRequestedQuantity = Math.max(
              0,
              curReq - unapprovedRequested,
            );
            (storeItem as any).stockAvailableQuantity =
              curAvail + unapprovedRequested;
          }

          // 2. If it was already approved, return Ready for Issue back to Available
          if (approvedUnissued > 0) {
            (storeItem as any).stockIssueQuantity = Math.max(
              0,
              curIssue - approvedUnissued,
            );
            (storeItem as any).stockAvailableQuantity =
              Number((storeItem as any).stockAvailableQuantity || 0) + approvedUnissued;
          }

          await storeItem.save();
          this.indentService
            .checkAndCancelAutoIndentIfStockRestored(
              String(storeItem._id),
              (storeItem as any).stockAvailableQuantity,
              `Auto-cancelled: Requisition ${issue.issNo} was rejected by ${rejectedBy || 'manager'} and stock restored.`,
            )
            .catch((err) =>
              console.error(
                'Auto indent cancel trigger error in rejectIssue:',
                err,
              ),
            );
        }
      }

      line.approvedQty = 0;
      line.approvedRejectQty = requested;
      rejectedQtyTotal += requested;
    }

    issue.status = 'REJECTED';
    (issue as any).rejectedBy = this.oid(rejectedBy);
    (issue as any).rejectedAt = new Date();
    (issue as any).expiresAt = null;
    if (reason) {
      const prevRemark = String(issue.remark || '').trim();
      issue.remark = prevRemark
        ? `${prevRemark} [Rejected: ${reason}]`
        : `[Rejected: ${reason}]`;
    }

    issue.markModified('lines');
    await issue.save();

    // Track event in audit log
    try {
      await this.track({
        type: 'REJECTED',
        qty: rejectedQtyTotal,
        operatedBy: rejectedBy,
        issue,
        note: `Requisition rejected (${rejectedQtyTotal} units). Reason: ${reason || 'N/A'}`,
      });
    } catch (trackErr) {
      console.warn('Stock track audit warning (non-fatal):', trackErr);
    }

    return {
      issueId: String(issue._id),
      issNo: (issue as any).issNo,
      status: issue.status,
      rejectedQtyTotal,
    };
  }

  /* ---------------- ISSUE ONE LINE ---------------- */

  async issueLine(issueId: string, dto: any) {
    const issuedBy = String(dto.issuedBy || '').trim();
    const itemId = String(dto.itemId || '').trim();
    const rackId = String(dto.rackId || '').trim();
    const qty = Number(dto.qty || 0);
    const reject = Number(dto.issuedRejectQty || 0);
    const totalCheck = qty + reject;

    if (!Types.ObjectId.isValid(issueId))
      throw new BadRequestException('issueId invalid');
    if (!Types.ObjectId.isValid(issuedBy))
      throw new BadRequestException('issuedBy invalid');
    if (!Types.ObjectId.isValid(itemId))
      throw new BadRequestException('itemId invalid');
    if (!Types.ObjectId.isValid(rackId))
      throw new BadRequestException('rackId invalid');
    if (!Number.isFinite(totalCheck) || totalCheck <= 0)
      throw new BadRequestException('qty invalid');
    if (!Number.isFinite(qty) || qty < 0)
      throw new BadRequestException('qty invalid');
    if (!Number.isFinite(reject) || reject < 0)
      throw new BadRequestException('qty invalid');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    const { line } = this.findLine(issue, itemId);

    const approvedQty = Number((line as any).approvedQty || 0);
    const issuedQty = Number((line as any).issuedQty || 0);
    const issuedRejectQty = Number((line as any).issuedRejectQty || 0);
    const canIssue = approvedQty - issuedQty - issuedRejectQty;

    if (canIssue <= 0)
      throw new BadRequestException('Nothing approved to issue for this item');

    if (qty > canIssue)
      throw new BadRequestException(
        `Qty exceeds approved remaining (${canIssue})`,
      );

    if (reject > canIssue)
      throw new BadRequestException(
        'Reject quantity exceeds approved quantity',
      );

    const storeItem = await this.itemModel.findById(this.oid(itemId));
    if (!storeItem) throw new BadRequestException('Store item not found');

    const storeCategory = await this.catModel.findById(
      this.oid(storeItem.categoryId),
    );
    if (!storeCategory)
      throw new BadRequestException('Store Category not found');

    const storeRack = await this.rackModel.findById(this.oid(rackId));
    if (!storeRack) throw new BadRequestException('Store rack not found');

    // ISS-RISK-005: Enforce division authorization check
    await this.checkDivisionAuthorization(issuedBy, String(issue.createdBy));

    // ISS-RISK-001: ItemRackQty MUST exist before any mutation
    const itemRackQty = await this.itemRackQtyModel.findOne({
      rackId: storeRack._id,
      itemId: storeItem._id,
    });
    if (!itemRackQty) {
      throw new BadRequestException(
        'Store rack item inventory record not found',
      );
    }

    // ISS-RISK-003: Rack-level stock validation
    // Note: global stockAvailableQuantity was already deducted when the request was approved
    const availRack = Number(itemRackQty.stockAvailableQuantity || 0);
    if (availRack < qty) {
      throw new BadRequestException(
        `Insufficient rack stock. Available in rack: ${availRack}`,
      );
    }

    // ISS-RISK-004: Execute with compensating rollback support
    return await this.executeIssueLineWithCompensation(
      issue,
      line,
      storeItem,
      storeCategory,
      storeRack,
      itemRackQty,
      qty,
      reject,
      issuedBy,
      dto,
    );
  }

  private async executeIssueLineWithCompensation(
    issue: any,
    line: any,
    storeItem: any,
    storeCategory: any,
    storeRack: any,
    itemRackQty: any,
    qty: number,
    reject: number,
    issuedBy: string,
    dto: any,
  ) {
    let itemStockUpdated = false;
    let irqStockUpdated = false;
    let issueUpdated = false;
    let createdTrackId: string | null = null;
    const createdBags: string[] = [];

    const origGlobalAvail = Number((storeItem as any).stockAvailableQuantity || 0);
    const origGlobalIssue = Number((storeItem as any).stockIssueQuantity || 0);
    const origStockLots = JSON.parse(JSON.stringify((storeItem as any).stockLots || []));

    const origRackAvail = Number(itemRackQty.stockAvailableQuantity || 0);
    const origRackIssue = Number(itemRackQty.stockIssueQuantity || 0);

    const origLineIssuedQty = Number((line as any).issuedQty || 0);
    const origLineIssuedRejectQty = Number((line as any).issuedRejectQty || 0);
    const origClosedAt = (issue as any).closedAt;
    const origAllocations = JSON.parse(
      JSON.stringify(issue.allocations || []),
    );

    try {
      // FIFO Lot Consumption
      let remainingToDeduct = qty;
      let totalIssueCost = 0;
      const consumedLots: Array<{ lotId: string; qty: number; unitPrice: number }> = [];

      const lots: any[] = Array.isArray((storeItem as any).stockLots)
        ? (storeItem as any).stockLots
        : [];

      // Sort lots by receivedAt ascending to guarantee oldest first (FIFO)
      lots.sort(
        (a: any, b: any) =>
          new Date(a.receivedAt || 0).getTime() - new Date(b.receivedAt || 0).getTime(),
      );

      for (const lot of lots) {
        if (remainingToDeduct <= 0) break;
        const lotAvail = Number(lot.remainingQty || 0);
        if (lotAvail > 0) {
          const deduct = Math.min(lotAvail, remainingToDeduct);
          lot.remainingQty = lotAvail - deduct;
          remainingToDeduct -= deduct;
          const lotRate = Number(lot.unitPrice || 0);
          totalIssueCost += deduct * lotRate;
          consumedLots.push({
            lotId: String(lot.lotId || ''),
            qty: deduct,
            unitPrice: lotRate,
          });
        }
      }

      if (remainingToDeduct > 0) {
        const fallbackRate = Number((storeItem as any).latestPurchasePrice || 0);
        totalIssueCost += remainingToDeduct * fallbackRate;
        consumedLots.push({
          lotId: 'historical',
          qty: remainingToDeduct,
          unitPrice: fallbackRate,
        });
      }

      const effectiveUnitPrice = qty > 0 ? totalIssueCost / qty : 0;

      // 1. Update Global Item Stock: move from Ready for Issue to Completed, persist FIFO lots
      (storeItem as any).stockIssueQuantity = Math.max(0, origGlobalIssue - qty);
      (storeItem as any).stockissueCompleted = Number((storeItem as any).stockissueCompleted || 0) + qty;
      (storeItem as any).stockLots = lots;
      storeItem.markModified('stockLots');
      await storeItem.save();
      itemStockUpdated = true;

      // 2. Update Rack Stock
      itemRackQty.stockAvailableQuantity = origRackAvail - qty;
      itemRackQty.stockIssueQuantity = origRackIssue + qty;
      await itemRackQty.save();
      irqStockUpdated = true;

      // 3. Update Issue Line & Allocations
      (line as any).issuedQty = origLineIssuedQty + qty;
      (line as any).issuedRejectQty = origLineIssuedRejectQty + reject;
      (line as any).unitPrice = effectiveUnitPrice;
      (line as any).totalPrice = Number((line as any).totalPrice || 0) + totalIssueCost;
      (line as any).consumedLots = [...((line as any).consumedLots || []), ...consumedLots];

      issue.allocations = issue.allocations || [];
      const rackOid = this.oid(storeRack._id);
      const itemOid = this.oid(storeItem._id);

      const existingIdx = issue.allocations.findIndex(
        (a: any) =>
          String(a.rackId) === String(rackOid) &&
          String(a.itemId) === String(itemOid),
      );

      if (existingIdx >= 0) {
        const prevQty = Number(issue.allocations[existingIdx].qty || 0);
        const prevTotal = Number(issue.allocations[existingIdx].totalPrice || 0);
        issue.allocations[existingIdx].qty = prevQty + qty;
        issue.allocations[existingIdx].totalPrice = prevTotal + totalIssueCost;
        issue.allocations[existingIdx].unitPrice =
          prevQty + qty > 0
            ? (prevTotal + totalIssueCost) / (prevQty + qty)
            : effectiveUnitPrice;
        issue.allocations[existingIdx].issuedAt = new Date();
        issue.allocations[existingIdx].issuedBy = this.oid(issuedBy);
      } else {
        issue.allocations.push({
          itemId: itemOid,
          itemName: (storeItem as any).itemName || (line as any).itemName,
          rackId: rackOid,
          rackName: (storeRack as any).code || '',
          qty,
          unitPrice: effectiveUnitPrice,
          totalPrice: totalIssueCost,
          returnedQty: 0,
          returnedGoodQty: 0,
          returnedScrapQty: 0,
          issuedAt: new Date(),
          issuedBy: this.oid(issuedBy),
        } as any);
      }

      if (!(issue as any).closedAt) {
        (issue as any).closedAt = new Date();
      }

      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();
      issueUpdated = true;

      // 4. Create Bags if required
      if (storeItem.maxCapacity && storeItem.maxCapacity > 0) {
        const counter = await this.bagModel.find({
          parentItemId: storeItem._id.toString(),
        });
        const endNo = counter.length;
        const startNo = counter.length + qty;

        for (let n = endNo; n < startNo; n++) {
          const payload: any = {
            parentItemId: storeItem._id.toString(),
            itemId: '',
            itemName: '',
            bagCode: this.formatBagCode(n + 1, (storeItem as any).itemName!),
            itemStock: 0,
            itemUsed: 0,
            approvedStatus: 'approved',
            transferType: 'inStock',
            transferQty: 0,
            maxQty: storeItem.maxCapacity,
          };
          const createdBag = await this.bagModel.create(payload);
          createdBags.push(String(createdBag._id));
        }
      }

      if (storeCategory.isMachine) {
        await this.disableAndAbleMachinesIfCategoryHasOutstandingIssues(
          storeItem.categoryId!,
        );
      }

      // 5. Track StockTrack with FIFO Unit Rate & Total Value
      const trackDoc = await this.stockTrackModel.create({
        type: 'ISSUE',
        qty: -qty,
        operatedBy: this.oid(issuedBy),
        refNo: issue.issNo ? String(issue.issNo) : '',
        note: `Issue line itemId=${storeItem._id} qty=${qty}${effectiveUnitPrice > 0 ? ' @ ₹' + effectiveUnitPrice.toFixed(2) + '/pc (Old Stock First)' : ''}`,
        itemId: this.oid(storeItem._id),
        categoryId: storeItem.categoryId ? this.asOid(storeItem.categoryId) : null,
        rackId: rackOid,
        issueId: this.oid(issue._id),
        receivingId: null,
        unitPrice: effectiveUnitPrice,
        totalPrice: totalIssueCost,
      });
      if (trackDoc) {
        createdTrackId = String(trackDoc._id);
      }

      return {
        updatedLine: {
          itemId: String((line as any).itemId),
          issuedQty: Number((line as any).issuedQty || 0),
          approvedQty: Number((line as any).approvedQty || 0),
          returnQty: Number((line as any).returnQty || 0),
          scrapQty: Number((line as any).scrapQty || 0),
          unitPrice: effectiveUnitPrice,
          totalPrice: totalIssueCost,
        },
      };
    } catch (err) {
      // COMPENSATING ROLLBACK
      if (createdTrackId) {
        await this.stockTrackModel.findByIdAndDelete(createdTrackId);
      }
      if (createdBags.length) {
        await this.bagModel.deleteMany({ _id: { $in: createdBags } });
      }
      if (issueUpdated) {
        (line as any).issuedQty = origLineIssuedQty;
        (line as any).issuedRejectQty = origLineIssuedRejectQty;
        issue.allocations = origAllocations;
        (issue as any).closedAt = origClosedAt;
        issue.markModified('lines');
        issue.markModified('allocations');
        await issue.save();
      }
      if (irqStockUpdated) {
        itemRackQty.stockAvailableQuantity = origRackAvail;
        itemRackQty.stockIssueQuantity = origRackIssue;
        await itemRackQty.save();
      }
      if (itemStockUpdated) {
        (storeItem as any).stockAvailableQuantity = origGlobalAvail;
        (storeItem as any).stockIssueQuantity = origGlobalIssue;
        (storeItem as any).stockLots = origStockLots;
        storeItem.markModified('stockLots');
        await storeItem.save();
      }
      throw err;
    }
  }

  private formatBagCode(bagNo: number, itemName: string) {
    return `${itemName}-${String(bagNo).padStart(6, '0')}`;
  }

  /* ---------------- ISSUE BULK ---------------- */

  async issueBulk(issueId: string, dto: IssueBulkDto) {
    const issuedBy = String(dto.issuedBy || '').trim();
    if (!Types.ObjectId.isValid(issueId))
      throw new BadRequestException('issueId invalid');
    if (!Types.ObjectId.isValid(issuedBy))
      throw new BadRequestException('issuedBy invalid');

    const lines = Array.isArray(dto.lines) ? dto.lines : [];
    if (!lines.length) throw new BadRequestException('No lines');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    // ISS-RISK-005: Enforce division authorization check
    await this.checkDivisionAuthorization(issuedBy, String(issue.createdBy));

    // PRE-VALIDATION & CUMULATIVE DEMAND AGGREGATION
    const preparedLines: Array<{
      line: any;
      storeItem: any;
      itemRackQty: any;
      storeRack: any;
      itemId: string;
      rackId: string;
      qty: number;
    }> = [];

    const itemCumulativeDemand: Record<string, number> = {};
    const rackCumulativeDemand: Record<string, number> = {};

    for (const l of lines) {
      const itemId = String((l as any).itemId || '').trim();
      const qty = Number((l as any).qty || 0);

      if (!Types.ObjectId.isValid(itemId))
        throw new BadRequestException('itemId invalid');
      if (!Number.isFinite(qty) || qty <= 0)
        throw new BadRequestException('qty invalid');

      const { line } = this.findLine(issue, itemId);
      const approvedQty = Number((line as any).approvedQty || 0);
      const issuedQty = Number((line as any).issuedQty || 0);
      const canIssue = approvedQty - issuedQty;

      if (qty > canIssue) {
        throw new BadRequestException(
          `Qty exceeds approved remaining for ${(line as any).itemName || itemId}`,
        );
      }

      const storeItem = await this.itemModel.findById(this.oid(itemId));
      if (!storeItem) throw new BadRequestException(`Store item not found: ${itemId}`);

      const rackId = String((l as any).rackId || (storeItem as any).rackId || '').trim();
      if (!rackId || !Types.ObjectId.isValid(rackId)) {
        throw new BadRequestException(`Valid rackId required for item ${(line as any).itemName || itemId}`);
      }

      const storeRack = await this.rackModel.findById(this.oid(rackId));
      if (!storeRack) throw new BadRequestException(`Store rack not found: ${rackId}`);

      const itemRackQty = await this.itemRackQtyModel.findOne({
        rackId: storeRack._id,
        itemId: storeItem._id,
      });
      if (!itemRackQty) {
        throw new BadRequestException(
          `ItemRackQty record not found for item ${(line as any).itemName || itemId} in rack ${storeRack.code}`,
        );
      }

      itemCumulativeDemand[itemId] = (itemCumulativeDemand[itemId] || 0) + qty;
      const rackKey = `${itemId}_${rackId}`;
      rackCumulativeDemand[rackKey] = (rackCumulativeDemand[rackKey] || 0) + qty;

      preparedLines.push({
        line,
        storeItem,
        itemRackQty,
        storeRack,
        itemId,
        rackId,
        qty,
      });
    }

    // Validate global available stock against cumulative demand
    for (const prep of preparedLines) {
      const globalAvail = Number((prep.storeItem as any).stockAvailableQuantity || 0);
      const demand = itemCumulativeDemand[prep.itemId];
      if (globalAvail < demand) {
        throw new BadRequestException(
          `Insufficient stock for ${(prep.storeItem as any).itemName}. Available: ${globalAvail}, Total Requested: ${demand}`,
        );
      }

      const rackKey = `${prep.itemId}_${prep.rackId}`;
      const rackAvail = Number(prep.itemRackQty.stockAvailableQuantity || 0);
      const rDemand = rackCumulativeDemand[rackKey];
      if (rackAvail < rDemand) {
        throw new BadRequestException(
          `Insufficient rack stock for ${(prep.storeItem as any).itemName} in rack ${prep.storeRack.code}. Available: ${rackAvail}, Total Requested: ${rDemand}`,
        );
      }
    }

    // ISS-RISK-004: Execute with compensating rollback
    return await this.executeIssueBulkWithCompensation(issue, preparedLines, issuedBy);
  }

  private async executeIssueBulkWithCompensation(
    issue: any,
    preparedLines: Array<{
      line: any;
      storeItem: any;
      itemRackQty: any;
      storeRack: any;
      itemId: string;
      rackId: string;
      qty: number;
    }>,
    issuedBy: string,
  ) {
    const mutatedItems: Array<{ doc: any; origAvail: number; origIssue: number }> = [];
    const mutatedItemRackQties: Array<{ doc: any; origAvail: number; origIssue: number }> = [];
    const createdTrackIds: string[] = [];
    const origClosedAt = (issue as any).closedAt;
    const origLines = JSON.parse(JSON.stringify(issue.lines || []));
    const origAllocations = JSON.parse(JSON.stringify(issue.allocations || []));

    const updatedLines: any[] = [];

    try {
      for (const prep of preparedLines) {
        const { line, storeItem, itemRackQty, storeRack, itemId, rackId, qty } = prep;

        // FIFO Lot Consumption
        let remainingToDeduct = qty;
        let totalIssueCost = 0;
        const consumedLots: Array<{ lotId: string; qty: number; unitPrice: number }> = [];

        const lots: any[] = Array.isArray((storeItem as any).stockLots)
          ? (storeItem as any).stockLots
          : [];

        lots.sort(
          (a: any, b: any) =>
            new Date(a.receivedAt || 0).getTime() - new Date(b.receivedAt || 0).getTime(),
        );

        for (const lot of lots) {
          if (remainingToDeduct <= 0) break;
          const lotAvail = Number(lot.remainingQty || 0);
          if (lotAvail > 0) {
            const deduct = Math.min(lotAvail, remainingToDeduct);
            lot.remainingQty = lotAvail - deduct;
            remainingToDeduct -= deduct;
            const lotRate = Number(lot.unitPrice || 0);
            totalIssueCost += deduct * lotRate;
            consumedLots.push({
              lotId: String(lot.lotId || ''),
              qty: deduct,
              unitPrice: lotRate,
            });
          }
        }

        if (remainingToDeduct > 0) {
          const fallbackRate = Number((storeItem as any).latestPurchasePrice || 0);
          totalIssueCost += remainingToDeduct * fallbackRate;
          consumedLots.push({
            lotId: 'historical',
            qty: remainingToDeduct,
            unitPrice: fallbackRate,
          });
        }

        const effectiveUnitPrice = qty > 0 ? totalIssueCost / qty : 0;

        // 1. Mutate Global Item Stock: move from Ready for Issue to Completed, persist FIFO lots
        const origGlobalAvail = Number((storeItem as any).stockAvailableQuantity || 0);
        const origGlobalIssue = Number((storeItem as any).stockIssueQuantity || 0);
        const origStockLots = JSON.parse(JSON.stringify((storeItem as any).stockLots || []));
        (storeItem as any).stockIssueQuantity = Math.max(0, origGlobalIssue - qty);
        (storeItem as any).stockissueCompleted = Number((storeItem as any).stockissueCompleted || 0) + qty;
        (storeItem as any).stockLots = lots;
        storeItem.markModified('stockLots');
        await storeItem.save();
        mutatedItems.push({ doc: storeItem, origAvail: origGlobalAvail, origIssue: origGlobalIssue, origStockLots } as any);

        // 2. Mutate Rack Stock (Fix ISS-RISK-002)
        const origRackAvail = Number(itemRackQty.stockAvailableQuantity || 0);
        const origRackIssue = Number(itemRackQty.stockIssueQuantity || 0);
        itemRackQty.stockAvailableQuantity = origRackAvail - qty;
        itemRackQty.stockIssueQuantity = origRackIssue + qty;
        await itemRackQty.save();
        mutatedItemRackQties.push({ doc: itemRackQty, origAvail: origRackAvail, origIssue: origRackIssue });

        // 3. Mutate Issue Line & Allocations
        const currentIssuedQty = Number((line as any).issuedQty || 0);
        (line as any).issuedQty = currentIssuedQty + qty;
        (line as any).unitPrice = effectiveUnitPrice;
        (line as any).totalPrice = Number((line as any).totalPrice || 0) + totalIssueCost;
        (line as any).consumedLots = [...((line as any).consumedLots || []), ...consumedLots];

        issue.allocations = issue.allocations || [];
        const rackOid = this.oid(storeRack._id);
        const itemOid = this.oid(storeItem._id);

        const existingIdx = issue.allocations.findIndex(
          (a: any) =>
            String(a.rackId) === String(rackOid) &&
            String(a.itemId) === String(itemOid),
        );

        if (existingIdx >= 0) {
          const prevQty = Number(issue.allocations[existingIdx].qty || 0);
          const prevTotal = Number(issue.allocations[existingIdx].totalPrice || 0);
          issue.allocations[existingIdx].qty = prevQty + qty;
          issue.allocations[existingIdx].totalPrice = prevTotal + totalIssueCost;
          issue.allocations[existingIdx].unitPrice =
            prevQty + qty > 0
              ? (prevTotal + totalIssueCost) / (prevQty + qty)
              : effectiveUnitPrice;
          issue.allocations[existingIdx].issuedAt = new Date();
          issue.allocations[existingIdx].issuedBy = this.oid(issuedBy);
        } else {
          issue.allocations.push({
            itemId: itemOid,
            itemName: (storeItem as any).itemName || (line as any).itemName,
            rackId: rackOid,
            rackName: (storeRack as any).code || '',
            qty,
            unitPrice: effectiveUnitPrice,
            totalPrice: totalIssueCost,
            returnedQty: 0,
            returnedGoodQty: 0,
            returnedScrapQty: 0,
            issuedAt: new Date(),
            issuedBy: this.oid(issuedBy),
          } as any);
        }

        // 4. Create StockTrack
        const trackDoc = await this.stockTrackModel.create({
          type: 'ISSUE',
          qty: -qty,
          operatedBy: this.oid(issuedBy),
          refNo: issue.issNo ? String(issue.issNo) : '',
          note: `Issue bulk itemId=${itemId} qty=${qty}${effectiveUnitPrice > 0 ? ' @ ₹' + effectiveUnitPrice.toFixed(2) + '/pc (Old Stock First)' : ''}`,
          itemId: itemOid,
          categoryId: storeItem.categoryId ? this.asOid(storeItem.categoryId) : null,
          rackId: rackOid,
          issueId: this.oid(issue._id),
          receivingId: null,
          unitPrice: effectiveUnitPrice,
          totalPrice: totalIssueCost,
        });
        if (trackDoc) {
          createdTrackIds.push(String(trackDoc._id));
        }

        updatedLines.push({ itemId, issuedQty: (line as any).issuedQty });
      }

      if (!(issue as any).closedAt) {
        (issue as any).closedAt = new Date();
      }

      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      return { updatedLines };
    } catch (err) {
      // COMPENSATING ROLLBACK
      if (createdTrackIds.length) {
        await this.stockTrackModel.deleteMany({ _id: { $in: createdTrackIds } });
      }
      issue.lines = origLines;
      issue.allocations = origAllocations;
      (issue as any).closedAt = origClosedAt;
      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      for (const m of mutatedItemRackQties) {
        m.doc.stockAvailableQuantity = m.origAvail;
        m.doc.stockIssueQuantity = m.origIssue;
        await m.doc.save();
      }
      for (const m of mutatedItems) {
        m.doc.stockAvailableQuantity = m.origAvail;
        m.doc.stockIssueQuantity = m.origIssue;
        if ((m as any).origStockLots) {
          m.doc.stockLots = (m as any).origStockLots;
          m.doc.markModified('stockLots');
        }
        await m.doc.save();
      }
      throw err;
    }
  }

  /* ---------------- RETURN LINE (good + scrap) ---------------- */

  async returnLine(issueId: string, dto: any) {
    const returnedBy = String(dto.returnedBy || '').trim();
    const itemId = String(dto.itemId || '').trim();
    const rackId = String(dto.rackId || '').trim();
    const scrapRackId = String(dto.scrapRackId || '').trim();

    const goodQty = Number(dto.goodQty ?? 0);
    const scrapQty = Number(dto.scrapQty ?? 0);
    const total = goodQty + scrapQty;

    if (!Types.ObjectId.isValid(issueId))
      throw new BadRequestException('issueId invalid');
    if (!Types.ObjectId.isValid(returnedBy))
      throw new BadRequestException('returnedBy invalid');
    if (!Types.ObjectId.isValid(itemId))
      throw new BadRequestException('itemId invalid');
    if (!Types.ObjectId.isValid(rackId))
      throw new BadRequestException('rackId invalid');

    if (!Number.isFinite(goodQty) || goodQty < 0)
      throw new BadRequestException('goodQty invalid');
    if (!Number.isFinite(scrapQty) || scrapQty < 0)
      throw new BadRequestException('scrapQty invalid');
    if (total <= 0) throw new BadRequestException('Nothing to return');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    const storeItem = await this.itemModel.findById(this.oid(itemId));
    if (!storeItem) throw new BadRequestException('Store item not found');

    const storeCategory = await this.catModel.findById(
      this.oid(storeItem.categoryId),
    );
    if (!storeCategory)
      throw new BadRequestException('Store Category not found');

    const storeRack = await this.rackModel.findById(this.oid(rackId));
    if (!storeRack) throw new BadRequestException('Store rack not found');

    const checkrack = await this.itemRackQtyModel.findOne({
      rackId: storeRack._id,
      itemId: storeItem._id,
    });
    if (!checkrack) throw new BadRequestException('Store rack item record not found');

    await this.checkDivisionAuthorization(returnedBy, String(issue.createdBy));

    const lineIndex = (issue.lines || []).findIndex(
      (l: any) => String(l.itemId) === String(itemId),
    );
    if (lineIndex < 0) throw new BadRequestException('Issue line not found');

    const line: any = issue.lines[lineIndex];
    const approvedQty = Number(line.approvedQty || 0);
    const issuedQty = Number(line.issuedQty || 0);
    const prevReturnQty = Number(line.returnQty || 0);
    const prevScrapQty = Number(line.scrapQty || 0);

    if (issuedQty < prevReturnQty + prevScrapQty) {
      throw new BadRequestException(
        `Corrupt line: issuedQty(${issuedQty}) < returned+scrap(${prevReturnQty + prevScrapQty})`,
      );
    }
    if (approvedQty < issuedQty) {
      throw new BadRequestException(
        `Corrupt line: approvedQty(${approvedQty}) < issuedQty(${issuedQty})`,
      );
    }

    const remainingToReturn = issuedQty - prevReturnQty - prevScrapQty;
    if (remainingToReturn <= 0) {
      throw new BadRequestException('Nothing pending to return');
    }
    if (total > remainingToReturn) {
      throw new BadRequestException(
        `Return exceeds remaining (${remainingToReturn})`,
      );
    }

    let scrapRack: any = null;
    let scrapItem: any = null;
    if (scrapQty > 0 && scrapRackId) {
      if (!Types.ObjectId.isValid(scrapRackId)) {
        throw new BadRequestException('scrapRackId invalid');
      }
      scrapRack = await this.rackModel.findById(this.oid(scrapRackId));
      if (!scrapRack) throw new BadRequestException('Scrap rack not found');
      if (scrapRack.itemId && String(scrapRack.itemId) !== itemId) {
        scrapItem = await this.itemModel.findById(this.oid(scrapRack.itemId));
      }
    }

    return await this.executeReturnLineWithCompensation(
      issue,
      line,
      storeItem,
      storeCategory,
      storeRack,
      checkrack,
      scrapRack,
      scrapItem,
      goodQty,
      scrapQty,
      total,
      returnedBy,
      dto,
    );
  }

  private async executeReturnLineWithCompensation(
    issue: any,
    line: any,
    storeItem: any,
    storeCategory: any,
    storeRack: any,
    checkrack: any,
    scrapRack: any,
    scrapItem: any,
    goodQty: number,
    scrapQty: number,
    total: number,
    returnedBy: string,
    dto: any,
  ) {
    let issueUpdated = false;
    let itemStockUpdated = false;
    let irqStockUpdated = false;
    let scrapItemUpdated = false;
    const modifiedBags: Array<{ id: string; prevStatus: string }> = [];
    const createdTrackIds: string[] = [];

    const origLineReturnQty = Number(line.returnQty || 0);
    const origLineScrapQty = Number(line.scrapQty || 0);
    const origAllocations = JSON.parse(JSON.stringify(issue.allocations || []));

    const origGlobalIssue = Number((storeItem as any).stockIssueQuantity || 0);
    const origGlobalAvail = Number((storeItem as any).stockAvailableQuantity || 0);
    const origGlobalScrap = Number((storeItem as any).stockscrapQuantity || 0);

    const origRackIssue = Number(checkrack.stockIssueQuantity || 0);
    const origRackAvail = Number(checkrack.stockAvailableQuantity || 0);
    const origRackScrap = Number(checkrack.stockscrapQuantity || 0);

    let origScrapTotalStock = 0;
    let origScrapAvailStock = 0;
    if (scrapItem) {
      origScrapTotalStock = Number((scrapItem as any).totalStockQuantity || 0);
      origScrapAvailStock = Number((scrapItem as any).stockAvailableQuantity || 0);
    }

    try {
      // 1. Bags
      if (storeItem.maxCapacity && storeItem.maxCapacity > 0) {
        const counter = await this.bagModel
          .find({ parentItemId: storeItem._id.toString(), itemId: '' })
          .sort({ createdAt: -1 });

        if (total > counter.length) {
          throw new BadRequestException(
            `Invalid return: total ${total} > counter.length ${counter.length}`,
          );
        }

        for (let n = 0; n < total; n++) {
          const bg = counter[n];
          modifiedBags.push({ id: String(bg._id), prevStatus: bg.approvedStatus });
          await this.bagModel.findByIdAndUpdate(bg._id, { approvedStatus: 'rejected' });
        }
      }

      // 2. Line & Allocations
      line.returnQty = origLineReturnQty + goodQty;
      line.scrapQty = origLineScrapQty + scrapQty;

      let needTotal = total;
      let needGood = goodQty;
      let needScrap = scrapQty;

      for (const a of issue.allocations || []) {
        if (needTotal <= 0) break;
        if (String((a as any).itemId) !== String(storeItem._id)) continue;

        const aq = Number((a as any).qty || 0);
        const ar = Number((a as any).returnedQty || 0);
        const free = aq - ar;
        if (free <= 0) continue;

        const take = Math.min(needTotal, free);
        (a as any).returnedQty = ar + take;

        const takeGood = Math.min(needGood, take);
        const takeScrap = Math.min(needScrap, take - takeGood);

        (a as any).returnedGoodQty = Number((a as any).returnedGoodQty || 0) + takeGood;
        (a as any).returnedScrapQty = Number((a as any).returnedScrapQty || 0) + takeScrap;

        needTotal -= take;
        needGood -= takeGood;
        needScrap -= takeScrap;
      }

      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();
      issueUpdated = true;

      // 3. Item Global Stock
      (storeItem as any).stockIssueQuantity = Math.max(0, origGlobalIssue - total);
      (storeItem as any).stockAvailableQuantity = origGlobalAvail + goodQty;
      (storeItem as any).stockscrapQuantity = origGlobalScrap + scrapQty;
      await storeItem.save();
      itemStockUpdated = true;

      // 4. Rack Stock
      checkrack.stockIssueQuantity = Math.max(0, origRackIssue - total);
      checkrack.stockAvailableQuantity = origRackAvail + goodQty;
      checkrack.stockscrapQuantity = origRackScrap + scrapQty;
      await checkrack.save();
      irqStockUpdated = true;

      // 5. Scrap Item if needed
      if (scrapItem && scrapQty > 0) {
        (scrapItem as any).totalStockQuantity = origScrapTotalStock + scrapQty;
        (scrapItem as any).stockAvailableQuantity = origScrapAvailStock + scrapQty;
        await scrapItem.save();
        scrapItemUpdated = true;
      }

      if (storeCategory.isMachine) {
        await this.disableAndAbleMachinesIfCategoryHasOutstandingIssues(
          storeItem.categoryId!,
        );
      }

      // 6. StockTracks
      if (goodQty > 0) {
        const trkGood = await this.stockTrackModel.create({
          type: 'RETURN',
          qty: +goodQty,
          operatedBy: this.oid(returnedBy),
          refNo: issue.issNo ? String(issue.issNo) : '',
          note: `Return goodQty=${goodQty}`,
          itemId: this.oid(storeItem._id),
          categoryId: storeItem.categoryId ? this.asOid(storeItem.categoryId) : null,
          rackId: this.oid(storeRack._id),
          issueId: this.oid(issue._id),
        });
        if (trkGood) createdTrackIds.push(String(trkGood._id));
      }

      if (scrapQty > 0) {
        const trkScrap = await this.stockTrackModel.create({
          type: 'SCRAP',
          qty: -scrapQty,
          operatedBy: this.oid(returnedBy),
          refNo: issue.issNo ? String(issue.issNo) : '',
          note: `Return scrapQty=${scrapQty}`,
          itemId: this.oid(storeItem._id),
          categoryId: storeItem.categoryId ? this.asOid(storeItem.categoryId) : null,
          rackId: scrapRack ? this.oid(scrapRack._id) : this.oid(storeRack._id),
          issueId: this.oid(issue._id),
        });
        if (trkScrap) createdTrackIds.push(String(trkScrap._id));
      }

      const out = {
        updatedLine: {
          itemId: String(line.itemId),
          approvedQty: Number(line.approvedQty || 0),
          issuedQty: Number(line.issuedQty || 0),
          returnQty: Number(line.returnQty || 0),
          scrapQty: Number(line.scrapQty || 0),
        },
      };
      return { data: out };
    } catch (err) {
      if (createdTrackIds.length) {
        await this.stockTrackModel.deleteMany({ _id: { $in: createdTrackIds } });
      }
      if (scrapItemUpdated && scrapItem) {
        (scrapItem as any).totalStockQuantity = origScrapTotalStock;
        (scrapItem as any).stockAvailableQuantity = origScrapAvailStock;
        await scrapItem.save();
      }
      if (irqStockUpdated) {
        checkrack.stockIssueQuantity = origRackIssue;
        checkrack.stockAvailableQuantity = origRackAvail;
        checkrack.stockscrapQuantity = origRackScrap;
        await checkrack.save();
      }
      if (itemStockUpdated) {
        (storeItem as any).stockIssueQuantity = origGlobalIssue;
        (storeItem as any).stockAvailableQuantity = origGlobalAvail;
        (storeItem as any).stockscrapQuantity = origGlobalScrap;
        await storeItem.save();
      }
      if (issueUpdated) {
        line.returnQty = origLineReturnQty;
        line.scrapQty = origLineScrapQty;
        issue.allocations = origAllocations;
        issue.markModified('lines');
        issue.markModified('allocations');
        await issue.save();
      }
      for (const b of modifiedBags) {
        await this.bagModel.findByIdAndUpdate(b.id, { approvedStatus: b.prevStatus });
      }
      throw err;
    }
  }

  /* ---------------- RETURN BULK (Hardened & Atomic) ---------------- */

  async returnBulk(issueId: string, dto: any) {
    const returnedBy = String(dto?.returnedBy || '').trim();
    if (!Types.ObjectId.isValid(issueId))
      throw new BadRequestException('issueId invalid');
    if (!Types.ObjectId.isValid(returnedBy))
      throw new BadRequestException('returnedBy invalid');

    const lines = Array.isArray(dto?.lines) ? dto.lines : [];
    if (!lines.length) throw new BadRequestException('No lines');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');

    await this.checkDivisionAuthorization(returnedBy, String(issue.createdBy));

    const linePlans: Array<{
      line: any;
      storeItem: any;
      checkrack: any;
      goodQty: number;
      scrapQty: number;
      total: number;
      rackId: string;
    }> = [];

    for (const l of lines) {
      const itemId = String(l?.itemId || '').trim();
      const goodQty = Number(l?.goodQty ?? 0);
      const scrapQty = Number(l?.scrapQty ?? 0);
      const total = goodQty + scrapQty;

      if (!Types.ObjectId.isValid(itemId))
        throw new BadRequestException('itemId invalid');
      if (!Number.isFinite(goodQty) || goodQty < 0)
        throw new BadRequestException('goodQty invalid');
      if (!Number.isFinite(scrapQty) || scrapQty < 0)
        throw new BadRequestException('scrapQty invalid');
      if (total <= 0) continue;

      const lineIndex = (issue.lines || []).findIndex(
        (ln: any) => String(ln.itemId) === String(itemId),
      );
      if (lineIndex < 0) throw new BadRequestException('Issue line not found');

      const line: any = issue.lines[lineIndex];
      const issuedQty = Number(line.issuedQty || 0);
      const returnedGood = Number(line.returnQty || 0);
      const returnedScrap = Number(line.scrapQty || 0);
      const remainingToReturn = issuedQty - returnedGood - returnedScrap;

      if (total > remainingToReturn) {
        throw new BadRequestException(
          `Return exceeds remaining (${remainingToReturn})`,
        );
      }

      const storeItem = await this.itemModel.findById(this.oid(itemId));
      if (!storeItem) throw new BadRequestException('Store item not found');

      let targetRackId = String(l?.rackId || '').trim();
      if (!targetRackId || !Types.ObjectId.isValid(targetRackId)) {
        const matchingAlloc = (issue.allocations || []).find(
          (a: any) => String(a.itemId) === String(itemId) && a.rackId,
        );
        if (matchingAlloc?.rackId) {
          targetRackId = String(matchingAlloc.rackId);
        } else if (storeItem.rackId) {
          const rawRack = Array.isArray(storeItem.rackId)
            ? storeItem.rackId[0]
            : storeItem.rackId;
          if (rawRack) targetRackId = String(rawRack);
        }
      }

      if (!targetRackId || !Types.ObjectId.isValid(targetRackId)) {
        throw new BadRequestException('Store rack not found');
      }

      const checkrack = await this.itemRackQtyModel.findOne({
        $or: [
          { rackId: targetRackId, itemId: String(storeItem._id) },
          { rackId: targetRackId, itemId: this.oid(storeItem._id) },
        ],
      });

      if (!checkrack) {
        throw new BadRequestException('Store rack item record not found');
      }

      linePlans.push({
        line,
        storeItem,
        checkrack,
        goodQty,
        scrapQty,
        total,
        rackId: targetRackId,
      });
    }

    if (!linePlans.length) {
      throw new BadRequestException('Nothing to return');
    }

    const origLines = JSON.parse(JSON.stringify(issue.lines || []));
    const origAllocations = JSON.parse(JSON.stringify(issue.allocations || []));

    const mutatedStoreItems: Array<{
      doc: any;
      origAvail: number;
      origIssue: number;
      origScrap: number;
    }> = [];

    const mutatedItemRackQties: Array<{
      doc: any;
      origAvail: number;
      origIssue: number;
      origScrap: number;
    }> = [];

    for (const plan of linePlans) {
      if (
        !mutatedStoreItems.some(
          (m) => String(m.doc._id) === String(plan.storeItem._id),
        )
      ) {
        mutatedStoreItems.push({
          doc: plan.storeItem,
          origAvail: Number((plan.storeItem as any).stockAvailableQuantity || 0),
          origIssue: Number((plan.storeItem as any).stockIssueQuantity || 0),
          origScrap: Number((plan.storeItem as any).stockscrapQuantity || 0),
        });
      }
      if (
        !mutatedItemRackQties.some(
          (m) => String(m.doc._id) === String(plan.checkrack._id),
        )
      ) {
        mutatedItemRackQties.push({
          doc: plan.checkrack,
          origAvail: Number(plan.checkrack.stockAvailableQuantity || 0),
          origIssue: Number(plan.checkrack.stockIssueQuantity || 0),
          origScrap: Number(plan.checkrack.stockscrapQuantity || 0),
        });
      }
    }

    const createdTrackIds: string[] = [];
    const updatedLines: any[] = [];

    try {
      for (const plan of linePlans) {
        const { line, storeItem, checkrack, goodQty, scrapQty, total, rackId } = plan;

        line.returnQty = Number(line.returnQty || 0) + goodQty;
        line.scrapQty = Number(line.scrapQty || 0) + scrapQty;

        let needTotal = total;
        let needGood = goodQty;
        let needScrap = scrapQty;

        for (const a of issue.allocations || []) {
          if (needTotal <= 0) break;
          if (String((a as any).itemId) !== String(storeItem._id)) continue;

          const aq = Number((a as any).qty || 0);
          const ar = Number((a as any).returnedQty || 0);
          const free = aq - ar;
          if (free <= 0) continue;

          const take = Math.min(needTotal, free);
          (a as any).returnedQty = ar + take;

          const takeGood = Math.min(needGood, take);
          const takeScrap = Math.min(needScrap, take - takeGood);

          (a as any).returnedGoodQty =
            Number((a as any).returnedGoodQty || 0) + takeGood;
          (a as any).returnedScrapQty =
            Number((a as any).returnedScrapQty || 0) + takeScrap;

          needTotal -= take;
          needGood -= takeGood;
          needScrap -= takeScrap;
        }

        const curGlobalIssue = Number((storeItem as any).stockIssueQuantity || 0);
        const curGlobalAvail = Number((storeItem as any).stockAvailableQuantity || 0);
        const curGlobalScrap = Number((storeItem as any).stockscrapQuantity || 0);

        (storeItem as any).stockIssueQuantity = Math.max(0, curGlobalIssue - total);
        (storeItem as any).stockAvailableQuantity = curGlobalAvail + goodQty;
        (storeItem as any).stockscrapQuantity = curGlobalScrap + scrapQty;
        await storeItem.save();

        const curRackIssue = Number(checkrack.stockIssueQuantity || 0);
        const curRackAvail = Number(checkrack.stockAvailableQuantity || 0);
        const curRackScrap = Number(checkrack.stockscrapQuantity || 0);

        checkrack.stockIssueQuantity = Math.max(0, curRackIssue - total);
        checkrack.stockAvailableQuantity = curRackAvail + goodQty;
        checkrack.stockscrapQuantity = curRackScrap + scrapQty;
        await checkrack.save();

        if (goodQty > 0) {
          const trkGood = await this.stockTrackModel.create({
            type: 'RETURN',
            qty: +goodQty,
            operatedBy: this.oid(returnedBy),
            refNo: issue.issNo ? String(issue.issNo) : '',
            note: `Return bulk goodQty=${goodQty}`,
            itemId: this.oid(storeItem._id),
            categoryId: storeItem.categoryId
              ? this.asOid(storeItem.categoryId)
              : null,
            rackId: this.oid(rackId),
            issueId: this.oid(issue._id),
          });
          if (trkGood) createdTrackIds.push(String(trkGood._id));
        }

        if (scrapQty > 0) {
          const trkScrap = await this.stockTrackModel.create({
            type: 'SCRAP',
            qty: -scrapQty,
            operatedBy: this.oid(returnedBy),
            refNo: issue.issNo ? String(issue.issNo) : '',
            note: `Return bulk scrapQty=${scrapQty}`,
            itemId: this.oid(storeItem._id),
            categoryId: storeItem.categoryId
              ? this.asOid(storeItem.categoryId)
              : null,
            rackId: this.oid(rackId),
            issueId: this.oid(issue._id),
          });
          if (trkScrap) createdTrackIds.push(String(trkScrap._id));
        }

        updatedLines.push({
          itemId: String(storeItem._id),
          returnQty: line.returnQty,
          scrapQty: line.scrapQty,
        });
      }

      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      return { updatedLines };
    } catch (err) {
      if (createdTrackIds.length) {
        await this.stockTrackModel.deleteMany({ _id: { $in: createdTrackIds } });
      }
      for (const m of mutatedItemRackQties) {
        m.doc.stockAvailableQuantity = m.origAvail;
        m.doc.stockIssueQuantity = m.origIssue;
        m.doc.stockscrapQuantity = m.origScrap;
        await m.doc.save();
      }
      for (const m of mutatedStoreItems) {
        m.doc.stockAvailableQuantity = m.origAvail;
        m.doc.stockIssueQuantity = m.origIssue;
        m.doc.stockscrapQuantity = m.origScrap;
        await m.doc.save();
      }
      issue.lines = origLines;
      issue.allocations = origAllocations;
      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      throw err;
    }
  }

  /* ---------------- ISSUE APPROVED (bucket distribution) ---------------- */

  async issueApproved(issueId: string, dto: any) {
    const issuedBy = String(dto?.issuedBy || '').trim();
    if (issuedBy && !Types.ObjectId.isValid(issuedBy))
      throw new BadRequestException('issuedBy invalid');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');
    // if (String(issue.status).toUpperCase() !== 'APPROVED')
    //   throw new BadRequestException('Only APPROVED can be issued');

    // const prevStatus = String(issue.status || '').toUpperCase();

    const line: any = issue.lines?.[0];
    if (!line) throw new BadRequestException('No issue line');

    const need = Number(line.approvedQty || 0);
    if (need <= 0) throw new BadRequestException('approvedQty is 0');

    const repItem = await this.itemModel.findById(line.itemId).lean();
    if (!repItem) throw new BadRequestException('Line item not found');

    const bucketCategoryId = String(dto?.bucketCategoryId || '').trim();
    if (!bucketCategoryId)
      throw new BadRequestException('bucketCategoryId required for issuing');

    const candidates = await this.itemModel
      .find({
        // itemNameId: (repItem as any).itemNameId,
        categoryId: this.oid(bucketCategoryId),
        stockAvailableQuantity: { $gt: 0 },
      })
      .select({
        categoryId: 1,
        rackId: 1,
        rackName: 1,
        itemName: 1,
        stockAvailableQuantity: 1,
        stockIssueQuantity: 1,
      })
      .sort({ stockAvailableQuantity: -1 })
      .lean();

    if (!candidates.length)
      throw new BadRequestException('No stock in selected category bucket');

    let remaining = need;
    const allocations: any[] = [];

    for (const it of candidates) {
      if (remaining <= 0) break;

      const av = Number((it as any).stockAvailableQuantity || 0);
      if (av <= 0) continue;

      const take = Math.min(av, remaining);

      await this.itemModel.updateOne(
        { _id: (it as any)._id },
        {
          $inc: {
            stockAvailableQuantity: -take,
            stockIssueQuantity: take,
          },
        },
      );

      allocations.push({
        itemId: (it as any)._id,
        itemName: (it as any).itemName ?? '',
        rackId: (it as any).rackId,
        rackName: (it as any).rackName ?? '',
        qty: take,
        returnedQty: 0,
        returnedGoodQty: 0,
        returnedScrapQty: 0,
        issuedAt: new Date(),
        issuedBy: issuedBy ? this.oid(issuedBy) : undefined,
      });

      // ✅ Track ISSUE per allocation (ISSUE negative)
      if (issuedBy) {
        await this.track({
          type: 'ISSUE',
          qty: -take,
          operatedBy: issuedBy,
          issue,
          item: it,
          itemId: (it as any)._id,
          note: `IssueApproved bucket=${bucketCategoryId} take=${take}`,
        });
      }

      remaining -= take;
    }

    const issuedTotal = need - remaining;
    if (issuedTotal <= 0)
      throw new BadRequestException('Not enough stock to issue');

    line.issuedQty = Number(line.issuedQty || 0) + issuedTotal;
    issue.allocations = [...(issue.allocations || []), ...allocations];

    // issue.status = this.computeCloseStatus(issue);
    if (
      // String(issue.status).toUpperCase() === 'CLOSED' &&
      !(issue as any).closedAt
    ) {
      (issue as any).closedAt = new Date();
    }

    issue.markModified('lines');
    issue.markModified('allocations');
    await issue.save();

    // ✅ Track CLOSED if changed
    if (issuedBy) {
      // await this.trackCloseIfChanged(prevStatus, issue, issuedBy);
    }

    return { issuedTotal, remaining };
  }

  /* ---------------- RETURN AGAINST ALLOCATION (Hardened & Atomic) ---------------- */

  async returnAgainstAllocation(issueId: string, dto: any) {
    const allocationId = String(dto?.allocationId || '').trim();
    const qty = Number(dto?.qty || 0);
    const returnedBy = String(dto?.returnedBy || '').trim();
    const scrapQty = Number(dto?.scrapQty || 0);
    const goodQty =
      dto?.goodQty !== undefined ? Number(dto.goodQty) : Math.max(0, qty - scrapQty);

    if (!Types.ObjectId.isValid(issueId))
      throw new BadRequestException('issueId invalid');
    if (!allocationId || !Types.ObjectId.isValid(allocationId))
      throw new BadRequestException('allocationId invalid');
    if (!returnedBy || !Types.ObjectId.isValid(returnedBy))
      throw new BadRequestException('returnedBy invalid');
    if (!Number.isFinite(qty) || qty <= 0)
      throw new BadRequestException('qty must be > 0');

    const issue = await this.issueModel.findById(this.oid(issueId));
    if (!issue) throw new BadRequestException('Issue not found');
    if (!issue.allocations?.length)
      throw new BadRequestException('No allocations found');

    await this.checkDivisionAuthorization(returnedBy, String(issue.createdBy));

    const alloc: any = issue.allocations.find(
      (a: any) => String(a._id) === allocationId,
    );
    if (!alloc) throw new BadRequestException('Allocation not found');

    const maxReturn = Number(alloc.qty || 0) - Number(alloc.returnedQty || 0);
    if (qty > maxReturn) {
      throw new BadRequestException(
        `Return qty exceeds remaining (${maxReturn})`,
      );
    }

    const storeItem = await this.itemModel.findById(this.oid(alloc.itemId));
    if (!storeItem) throw new BadRequestException('Store item not found');

    let targetRackId = alloc.rackId ? String(alloc.rackId) : '';
    if (!targetRackId || !Types.ObjectId.isValid(targetRackId)) {
      if (storeItem.rackId) {
        const rawRack = Array.isArray(storeItem.rackId)
          ? storeItem.rackId[0]
          : storeItem.rackId;
        if (rawRack) targetRackId = String(rawRack);
      }
    }

    if (!targetRackId || !Types.ObjectId.isValid(targetRackId)) {
      throw new BadRequestException('Store rack not found');
    }

    const checkrack = await this.itemRackQtyModel.findOne({
      $or: [
        { rackId: targetRackId, itemId: String(storeItem._id) },
        { rackId: targetRackId, itemId: this.oid(storeItem._id) },
      ],
    });

    const origLines = JSON.parse(JSON.stringify(issue.lines || []));
    const origAllocations = JSON.parse(JSON.stringify(issue.allocations || []));

    const origGlobalIssue = Number((storeItem as any).stockIssueQuantity || 0);
    const origGlobalAvail = Number((storeItem as any).stockAvailableQuantity || 0);
    const origGlobalScrap = Number((storeItem as any).stockscrapQuantity || 0);

    const origRackIssue = checkrack ? Number(checkrack.stockIssueQuantity || 0) : 0;
    const origRackAvail = checkrack ? Number(checkrack.stockAvailableQuantity || 0) : 0;
    const origRackScrap = checkrack ? Number(checkrack.stockscrapQuantity || 0) : 0;

    const createdTrackIds: string[] = [];

    try {
      alloc.returnedQty = Number(alloc.returnedQty || 0) + qty;
      alloc.returnedGoodQty = Number(alloc.returnedGoodQty || 0) + goodQty;
      alloc.returnedScrapQty = Number(alloc.returnedScrapQty || 0) + scrapQty;

      const line: any = (issue.lines || []).find(
        (l: any) => String(l.itemId) === String(alloc.itemId),
      );
      if (line) {
        line.returnQty = Number(line.returnQty || 0) + goodQty;
        line.scrapQty = Number(line.scrapQty || 0) + scrapQty;
      }

      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      (storeItem as any).stockIssueQuantity = Math.max(0, origGlobalIssue - qty);
      (storeItem as any).stockAvailableQuantity = origGlobalAvail + goodQty;
      (storeItem as any).stockscrapQuantity = origGlobalScrap + scrapQty;
      await storeItem.save();

      if (checkrack) {
        checkrack.stockIssueQuantity = Math.max(0, origRackIssue - qty);
        checkrack.stockAvailableQuantity = origRackAvail + goodQty;
        checkrack.stockscrapQuantity = origRackScrap + scrapQty;
        await checkrack.save();
      }

      if (goodQty > 0) {
        const trkGood = await this.stockTrackModel.create({
          type: 'RETURN',
          qty: +goodQty,
          operatedBy: this.oid(returnedBy),
          refNo: issue.issNo ? String(issue.issNo) : '',
          note: `ReturnAgainstAllocation qty=${goodQty} allocationId=${allocationId}`,
          itemId: this.oid(storeItem._id),
          categoryId: storeItem.categoryId
            ? this.asOid(storeItem.categoryId)
            : null,
          rackId: this.oid(targetRackId),
          issueId: this.oid(issue._id),
        });
        if (trkGood) createdTrackIds.push(String(trkGood._id));
      }

      if (scrapQty > 0) {
        const trkScrap = await this.stockTrackModel.create({
          type: 'SCRAP',
          qty: -scrapQty,
          operatedBy: this.oid(returnedBy),
          refNo: issue.issNo ? String(issue.issNo) : '',
          note: `ReturnAgainstAllocation scrapQty=${scrapQty} allocationId=${allocationId}`,
          itemId: this.oid(storeItem._id),
          categoryId: storeItem.categoryId
            ? this.asOid(storeItem.categoryId)
            : null,
          rackId: this.oid(targetRackId),
          issueId: this.oid(issue._id),
        });
        if (trkScrap) createdTrackIds.push(String(trkScrap._id));
      }

      return true;
    } catch (err) {
      if (createdTrackIds.length) {
        await this.stockTrackModel.deleteMany({ _id: { $in: createdTrackIds } });
      }
      if (checkrack) {
        checkrack.stockIssueQuantity = origRackIssue;
        checkrack.stockAvailableQuantity = origRackAvail;
        checkrack.stockscrapQuantity = origRackScrap;
        await checkrack.save();
      }
      (storeItem as any).stockIssueQuantity = origGlobalIssue;
      (storeItem as any).stockAvailableQuantity = origGlobalAvail;
      (storeItem as any).stockscrapQuantity = origGlobalScrap;
      await storeItem.save();

      issue.lines = origLines;
      issue.allocations = origAllocations;
      issue.markModified('lines');
      issue.markModified('allocations');
      await issue.save();

      throw err;
    }
  }
  escapeRegex(input: string) {
    return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
  async findIssuesByLineItemId(dto: any) {
    const itemId = String(dto?.itemId ?? '').trim();
    if (!itemId) return [];

    const search = String(dto?.search ?? '').trim();
    const createdBy = String(dto?.createdBy ?? '').trim();

    // Prepare the query to handle different storage formats of itemId
    const or: any[] = [
      { 'lines.itemId': itemId }, // if stored as string
      { 'lines.itemId.$oid': itemId }, // if stored as { $oid: "..." }
    ];

    // If itemId is a valid ObjectId, we also check for ObjectId storage
    if (Types.ObjectId.isValid(itemId)) {
      or.unshift({ 'lines.itemId': new Types.ObjectId(itemId) }); // if stored as ObjectId
    }

    // ✅ build filter
    const filter: any = { $or: or };

    // ✅ createdBy is STRING in schema => direct match only
    if (createdBy) {
      filter.createdBy = createdBy;
    }

    // ✅ search ONLY by issNo
    if (search) {
      const re = new RegExp(this.escapeRegex(search), 'i');
      filter.issNo = re;
    }

    // Fetch issues from the database
    const issues = await this.issueModel.find(filter).lean();

    const filteredIssues = issues
      .map((issue) => {
        const filteredLines = (issue.lines ?? []).filter((line) => {
          const lineItemId =
            line.itemId?.toString?.() ?? String(line.itemId ?? '');
          if (lineItemId !== itemId) return false;

          // Safely coerce numbers (avoid undefined / null)
          const requestedQty = Number(line.requestedQty ?? 0);
          const approvedQty = Number(line.approvedQty ?? 0);
          const issuedQty = Number(line.issuedQty ?? 0);
          const returnQty = Number(line.returnQty ?? 0);
          const scrapQty = Number(line.scrapQty ?? 0);
          const approvedRejectQty = Number(line.approvedRejectQty ?? 0);
          const issuedRejectQty = Number(line.issuedRejectQty ?? 0);

          // "Completed" condition as per your rules
          const isCompleted =
            requestedQty === approvedQty + approvedRejectQty &&
            approvedQty === issuedQty + issuedRejectQty &&
            issuedQty === returnQty + scrapQty;

          // ✅ Keep ONLY non-completed lines
          return !isCompleted;
        });

        return { ...issue, lines: filteredLines };
      })
      // ✅ Remove issues that have no remaining lines
      .filter((issue) => issue.lines.length > 0);

    return filteredIssues;
  }

  async getItemIssueBreakdown(itemId: any) {
    if (Array.isArray(itemId)) {
      itemId = itemId[0];
    }
    if (!itemId) return { requested: [], readyForIssue: [], history: [] };
    itemId = String(itemId).trim();
    if (!itemId) return { requested: [], readyForIssue: [], history: [] };

    let storeItem: any = null;
    if (Types.ObjectId.isValid(itemId)) {
      storeItem = await this.itemModel.findById(new Types.ObjectId(itemId)).lean().exec();
    }
    const currentStockIssueQty = Number(storeItem?.stockIssueQuantity || 0);
    const currentStockReqQty = Number(storeItem?.stockRequestedQuantity || 0);

    const or: any[] = [
      { 'lines.itemId': itemId },
      { 'lines.itemId.$oid': itemId },
    ];
    if (Types.ObjectId.isValid(itemId)) {
      or.unshift({ 'lines.itemId': new Types.ObjectId(itemId) });
    }

    const issues = await this.issueModel
      .find({ $or: or })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean()
      .exec();

    const userIdsSet = new Set<string>();
    for (const issue of issues) {
      if (issue.createdBy) userIdsSet.add(String(issue.createdBy));
      if (issue.approvedBy) userIdsSet.add(String(issue.approvedBy));
      if ((issue as any).rejectedBy) userIdsSet.add(String((issue as any).rejectedBy));
      if ((issue as any).closedBy) userIdsSet.add(String((issue as any).closedBy));
      if ((issue as any).revertedBy) userIdsSet.add(String((issue as any).revertedBy));
      for (const a of (issue.allocations || [])) {
        if (a?.issuedBy) userIdsSet.add(String(a.issuedBy));
      }
    }

    const userMap = await this.userService.findUsersWithDivisionMap(
      Array.from(userIdsSet),
    );

    const requestedList: any[] = [];
    const readyForIssueList: any[] = [];
    const historyList: any[] = [];
    const now = Date.now();
    let remainingReadyBudget = currentStockIssueQty;
    let remainingReqBudget = currentStockReqQty;

    for (const issue of issues) {
      const st = String(issue.status || '').toUpperCase();
      const isReverted = !!(issue as any).revertedAt;
      const isClosed = !!(issue as any).closedAt || st === 'CLOSED';
      const isRejected = st === 'REJECTED';

      const matchingLines = (issue.lines || []).filter((l: any) => {
        const lid = l.itemId?.toString?.() ?? String(l.itemId ?? '');
        return lid === itemId;
      });

      if (matchingLines.length === 0) continue;

      const creator = userMap.get(String(issue.createdBy));
      const approver = userMap.get(String(issue.approvedBy));
      const rejector = userMap.get(String((issue as any).rejectedBy));
      const closer = userMap.get(String((issue as any).closedBy));
      const reverter = userMap.get(String((issue as any).revertedBy));

      let dept =
        (issue as any).departmentName ||
        (issue as any).divisionName ||
        creator?.department ||
        '';

      if (!dept || /^[0-9a-fA-F]{24}$/.test(dept.trim())) {
        dept = creator?.department && !/^[0-9a-fA-F]{24}$/.test(creator.department.trim())
          ? creator.department
          : 'General Operations';
      }

      const userName =
        creator?.name || 'Requester ' + String(issue.createdBy || '').slice(-4);
      const approverName =
        approver?.name ||
        (issue.approvedBy
          ? 'Approver ' + String(issue.approvedBy).slice(-4)
          : '');
      const rejectorName =
        rejector?.name ||
        ((issue as any).rejectedBy
          ? 'Authority ' + String((issue as any).rejectedBy).slice(-4)
          : 'Management');
      const reverterName =
        reverter?.name ||
        ((issue as any).revertedBy
          ? 'Approver ' + String((issue as any).revertedBy).slice(-4)
          : 'Management');

      for (const line of matchingLines) {
        const reqQty = Number(line.requestedQty || 0);
        const appQty = Number(line.approvedQty || 0);
        const appRejQty = Number(line.approvedRejectQty || 0);
        const issQty = Number(line.issuedQty || 0);
        const issRejQty = Number(line.issuedRejectQty || 0);

        // Matching allocations for this item
        const matchingAllocations = (issue.allocations || []).filter((a: any) => {
          const aid = a?.itemId?.toString?.() ?? String(a?.itemId ?? '');
          return aid === itemId;
        });

        const allocatedQty = matchingAllocations.reduce(
          (sum: number, a: any) => sum + Number(a?.qty || 0),
          0,
        );
        const totalAlreadyIssued = Math.max(issQty, allocatedQty);

        // 1. DRAFT (Pending Requisition) & Requisition Stage
        const isDraft = st === 'DRAFT';
        const timeoutMs = this.storeCartService?.getRequestTimeoutMs();
        const isExpired =
          st === 'EXPIRED' ||
          (isDraft &&
            timeoutMs !== null &&
            ((issue.expiresAt && new Date(issue.expiresAt).getTime() < now) ||
              ((issue as any).createdAt &&
                now - new Date((issue as any).createdAt).getTime() >= timeoutMs)));

        if (isDraft && !isExpired && !isReverted && currentStockReqQty > 0 && remainingReqBudget > 0) {
          const pendingReqQty = Math.max(0, reqQty - appQty - appRejQty);
          if (pendingReqQty > 0) {
            const takeQty = Math.min(pendingReqQty, remainingReqBudget);
            requestedList.push({
              issueId: String(issue._id),
              issNo: String(issue.issNo || ''),
              userId: String(issue.createdBy || ''),
              userName,
              department: dept,
              status: 'DRAFT',
              isPending: true,
              quantity: takeQty,
              reason: String(issue.reason || ''),
              remark: String(issue.remark || ''),
              createdAt: (issue as any).createdAt,
              expiresAt: (issue as any).expiresAt,
            });
            remainingReqBudget -= takeQty;
          }
        } else {
          // Track all requested requisitions that moved to other stages
          requestedList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: st,
            isPending: false,
            quantity: reqQty,
            reason: String(issue.reason || ''),
            remark: String(issue.remark || ''),
            createdAt: (issue as any).createdAt,
            approvedAt: (issue as any).approvedAt,
            rejectedAt: (issue as any).rejectedAt,
            approvedByName: approverName,
            rejectedByName: rejectorName,
          });
        }

        // 2. APPROVED (Ready for Counter Issue Stage)
        const isApproved = st === 'APPROVED';
        if (isApproved && !isClosed && !isReverted && currentStockIssueQty > 0 && remainingReadyBudget > 0) {
          const readyQty = Math.max(0, appQty - totalAlreadyIssued - issRejQty);
          if (readyQty > 0) {
            const takeQty = Math.min(readyQty, remainingReadyBudget);
            readyForIssueList.push({
              issueId: String(issue._id),
              issNo: String(issue.issNo || ''),
              userId: String(issue.createdBy || ''),
              userName,
              department: dept,
              status: 'APPROVED',
              isPending: true,
              quantity: takeQty,
              approvedBy: String(issue.approvedBy || ''),
              approvedByName: approverName,
              reason: String(issue.reason || ''),
              remark: String(issue.remark || ''),
              createdAt: (issue as any).createdAt,
              approvedAt:
                (issue as any).approvedAt ||
                (issue as any).updatedAt ||
                (issue as any).createdAt,
            });
            remainingReadyBudget -= takeQty;
          }
        } else if (appQty > 0 || (issue as any).approvedAt || totalAlreadyIssued > 0) {
          // Track items that passed through or reached the counter
          readyForIssueList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: isClosed || totalAlreadyIssued > 0 ? (isClosed ? 'CLOSED' : 'PICKED UP') : (isReverted ? 'REVERTED_APPROVAL' : st),
            isPending: false,
            quantity: appQty > 0 ? appQty : reqQty,
            approvedBy: String(issue.approvedBy || ''),
            approvedByName: approverName,
            approvedAt: (issue as any).approvedAt,
            reason: String(issue.reason || ''),
            remark: String(issue.remark || ''),
            createdAt: (issue as any).createdAt,
          });
        }

        // 3. HISTORY: TERMINAL / LIFECYCLE AUDIT RECORDS
        if (isRejected || appRejQty > 0) {
          historyList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: 'REJECTED',
            quantity: appRejQty > 0 ? appRejQty : reqQty,
            rejectedBy: String((issue as any).rejectedBy || ''),
            rejectedByName: rejectorName,
            rejectedAt: (issue as any).rejectedAt || (issue as any).updatedAt,
            reason: String(issue.reason || ''),
            remark: String(issue.remark || ''),
            createdAt: (issue as any).createdAt,
          });
        } else if (isExpired) {
          const isMonthEnd =
            String(issue.remark || '').toLowerCase().includes('month end') ||
            String(issue.remark || '').toLowerCase().includes('unclaimed');
          const days = Math.max(1, Math.round((timeoutMs || 604800000) / (24 * 60 * 60 * 1000)));
          const defaultRemark = isMonthEnd
            ? 'Auto-revert: Monthly unclaimed timeline reached at store counter'
            : `Auto-revert: Weekly (${days} days) requisition timeline reached without approval`;

          historyList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: isMonthEnd ? 'EXPIRED_MONTH_END' : 'EXPIRED_WEEKLY',
            revertType: isMonthEnd ? 'MONTH_END_AUTO_REVERT' : 'WEEKLY_7_DAY_AUTO_REVERT',
            quantity: isMonthEnd && appQty > 0 ? appQty : reqQty,
            approvedBy: String(issue.approvedBy || ''),
            approvedByName: approverName,
            approvedAt: (issue as any).approvedAt,
            revertedAt: (issue as any).updatedAt || (issue as any).createdAt,
            reason: String(issue.reason || ''),
            remark: String(issue.remark || defaultRemark),
            createdAt: (issue as any).createdAt,
          });
        } else if (isReverted) {
          historyList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: 'REVERTED_APPROVAL',
            revertType: 'MANUAL_APPROVAL_REVERT',
            quantity: appQty > 0 ? appQty : reqQty,
            approvedBy: String(issue.approvedBy || ''),
            approvedByName: approverName,
            approvedAt: (issue as any).approvedAt,
            revertedBy: String((issue as any).revertedBy || ''),
            revertedByName: reverterName,
            revertedAt: (issue as any).revertedAt,
            revertReason: (issue as any).revertReason || '',
            reason: String(issue.reason || ''),
            remark: (issue as any).revertReason
              ? `Approval reverted: ${(issue as any).revertReason}`
              : 'Approval reverted by management',
            createdAt: (issue as any).createdAt,
          });
        } else if (totalAlreadyIssued > 0 || isClosed) {
          // Handed over at store counter
          const firstAlloc = matchingAllocations[0];
          const latestAlloc = matchingAllocations[matchingAllocations.length - 1];
          const issuer = latestAlloc?.issuedBy ? userMap.get(String(latestAlloc.issuedBy)) : closer;
          const issuedByName = issuer?.name || (latestAlloc?.issuedBy ? 'Staff ' + String(latestAlloc.issuedBy).slice(-4) : 'Store Counter');

          historyList.push({
            issueId: String(issue._id),
            issNo: String(issue.issNo || ''),
            userId: String(issue.createdBy || ''),
            userName,
            department: dept,
            status: isClosed ? 'CLOSED' : 'PICKED UP',
            quantity: totalAlreadyIssued > 0 ? totalAlreadyIssued : (appQty > 0 ? appQty : reqQty),
            approvedBy: String(issue.approvedBy || ''),
            approvedByName: approverName,
            approvedAt: (issue as any).approvedAt,
            issuedBy: String(latestAlloc?.issuedBy || (issue as any).closedBy || ''),
            issuedByName,
            issuedAt: latestAlloc?.issuedAt || (issue as any).closedAt || (issue as any).updatedAt,
            racks: matchingAllocations.map((a: any) => ({
              rackName: a.rackName || 'Stock Rack',
              qty: a.qty,
              unitPrice: a.unitPrice || 0,
              totalPrice: a.totalPrice || 0,
              issuedAt: a.issuedAt,
            })),
            unitPrice: Number(line.unitPrice || (matchingAllocations[0] as any)?.unitPrice || 0),
            totalPrice: Number(line.totalPrice || (matchingAllocations[0] as any)?.totalPrice || 0),
            consumedLots: line.consumedLots || [],
            reason: String(issue.reason || ''),
            remark: String(issue.remark || ''),
            createdAt: (issue as any).createdAt,
          });
        }
      }
    }

    return {
      requested: requestedList,
      readyForIssue: readyForIssueList,
      history: historyList,
      stockLots: storeItem?.stockLots || [],
      latestPurchasePrice: Number(storeItem?.latestPurchasePrice || 0),
    };
  }

  // async findIssuesByLineItemId(itemId: string) {
  //   // Prepare the query to handle different storage formats of itemId
  //   const or: any[] = [
  //     { 'lines.itemId': itemId }, // if stored as string
  //     { 'lines.itemId.$oid': itemId }, // if stored as { $oid: "..." }
  //   ];

  //   // If itemId is a valid ObjectId, we also check for ObjectId storage
  //   if (Types.ObjectId.isValid(itemId)) {
  //     or.unshift({ 'lines.itemId': new Types.ObjectId(itemId) }); // if stored as ObjectId
  //   }

  //   // Fetch issues from the database
  //   const issues = await this.issueModel.find({ $or: or }).lean();

  //   // Filter lines to match the itemId in the lines array
  //   const filteredIssues = issues.map((issue) => {
  //     // Filter lines that match the itemId
  //     const filteredLines = issue.lines.filter((line) => {
  //       const lineItemId = line.itemId?.toString(); // Convert ObjectId to string if necessary
  //       return lineItemId === itemId;
  //     });

  //     // Return the issue with only the matching lines
  //     return { ...issue, lines: filteredLines };
  //   });

  //   return filteredIssues;
  // }

  /* ---------------- FIND PAGED ---------------- */

  async findAllIssuesPaged(dto: any) {
    const page = Math.max(1, Number(dto.page || 1));
    const limit = Math.min(200, Math.max(1, Number(dto.limit || 12)));
    const skip = (page - 1) * limit;

    const search = String(dto?.search || '').trim();
    const createdByRaw = String(dto?.createdBy || '').trim();
    const status = String(dto?.status || '')
      .trim()
      .toUpperCase();

    const tab = String(dto?.tab || '').trim().toLowerCase();

    const filter: any = {};
    if (status && status !== 'ALL') {
      filter.status = status;
    } else if (tab === 'ready') {
      filter.status = { $nin: ['CLOSED', 'REJECTED', 'EXPIRED'] };
      filter.closedAt = null;
    } else if (tab === 'history') {
      filter.$or = [
        { status: { $in: ['CLOSED', 'REJECTED', 'EXPIRED'] } },
        { closedAt: { $ne: null } },
        { 'allocations.0': { $exists: true } },
        { 'lines.issuedQty': { $gt: 0 } },
      ];
    }

    if (createdByRaw) {
      if (Types.ObjectId.isValid(createdByRaw)) {
        filter.createdBy = { $in: [createdByRaw, this.oid(createdByRaw)] };
      } else {
        filter.createdBy = createdByRaw;
      }
    }

    if (search) {
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp(escaped, 'i');
      const searchOr = [{ issNo: re }, { reason: re }, { 'lines.itemName': re }];
      if (filter.$or) {
        filter.$and = [{ $or: filter.$or }, { $or: searchOr }];
        delete filter.$or;
      } else {
        filter.$or = searchOr;
      }
    }

    const [total, rows] = await Promise.all([
      this.issueModel.countDocuments(filter),
      this.issueModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
    ]);

    // Fast batch user resolution for audit milestones
    try {
      const userIdsSet = new Set<string>();
      for (const r of rows) {
        if (r.createdBy) userIdsSet.add(String(r.createdBy));
        if (r.approvedBy) userIdsSet.add(String(r.approvedBy));
        if ((r as any).rejectedBy) userIdsSet.add(String((r as any).rejectedBy));
        if ((r as any).closedBy) userIdsSet.add(String((r as any).closedBy));
        for (const a of (r.allocations || [])) {
          if (a?.issuedBy) userIdsSet.add(String(a.issuedBy));
        }
      }
      if (userIdsSet.size > 0) {
        const userMap = await this.userService.findUsersWithDivisionMap(
          Array.from(userIdsSet),
        );
        for (const r of rows) {
          const creator = userMap.get(String(r.createdBy));
          const approver = userMap.get(String(r.approvedBy));
          const rejector = userMap.get(String((r as any).rejectedBy));
          const closer = userMap.get(String((r as any).closedBy));

          (r as any).creatorName = creator?.name || '';
          if (!(r as any).departmentName || /^[0-9a-fA-F]{24}$/.test(String((r as any).departmentName).trim())) {
            (r as any).departmentName = creator?.department || 'General Operations';
          }
          (r as any).approvedByName = approver?.name || '';
          (r as any).rejectedByName = rejector?.name || '';
          (r as any).closedByName = closer?.name || '';

          for (const a of (r.allocations || [])) {
            if (a?.issuedBy) {
              const issuer = userMap.get(String(a.issuedBy));
              (a as any).issuedByName = issuer?.name || '';
            }
          }
        }
      }
    } catch (uErr) {
      // Non-fatal fallback
    }

    return {
      rows,
      total,
      page,
      limit,
      tab: tab || 'all',
    };
  }

  async getMachineCategoriesWithIssuedItems(): Promise<{
    ok: boolean;
    msg: string;
    categories: CategoryWithIssuedItems[];
  }> {
    // 1) Categories: parentId not empty + isMachine true
    // parentId is array => $expr + $size (safe)
    let categories = await this.catModel
      .find({
        isMachine: true,
        $expr: { $gt: [{ $size: { $ifNull: ['$parentId', []] } }, 0] },
      })
      .lean();

    if (!categories.length) {
      return { ok: true, msg: 'categories not present', categories: [] };
    }
    const allCategoryIds = categories.map((c: any) => c._id.toString());

    // ✅ NEW STEP: Exclude categories that already exist in Machine collection
    const machineCats = await this.machineModel
      .find(
        { categoryId: { $in: allCategoryIds } }, // Machine.categoryId is string
        { categoryId: 1, _id: 0 },
      )
      .lean();

    const machineCategorySet = new Set<string>(
      machineCats.map((m: any) => (m.categoryId ?? '').toString().trim()),
    );

    categories = categories.filter(
      (c: any) => !machineCategorySet.has(c._id.toString()),
    );

    if (!categories.length) {
      return {
        ok: true,
        msg: 'all categories already exist in machine data',
        categories: [],
      };
    }

    const categoryIds = categories.map((c: any) => c._id.toString());

    // 2) Items by categoryId (categoryId is stored as string in StoreNewItem)
    const items = await this.itemModel
      .find(
        { categoryId: { $in: categoryIds } },
        { itemCode: 1, itemName: 1, categoryId: 1 }, // _id is included by default
      )
      .lean();

    if (!items.length) {
      return { ok: true, msg: 'items not present', categories: [] };
    }

    // 3) Build ObjectId list for matching ItemIssue.lines.itemId (which is actually stored as ObjectId in your data)
    const itemObjectIds: Types.ObjectId[] = items
      .map((i: any) => i._id?.toString?.() ?? '')
      .filter((id: string) => Types.ObjectId.isValid(id))
      .map((id: string) => new Types.ObjectId(id));

    if (!itemObjectIds.length) {
      return { ok: true, msg: 'no valid item ids', categories: [] };
    }

    // 4) Aggregate netIssued per item + collect issueNos
    // netIssued = issuedQty - (returnQty + scrapQty)
    const agg: Array<{
      itemId: string;
      netIssued: number;
      issueNos: string[];
    }> = await this.issueModel.aggregate([
      { $unwind: '$lines' },

      // ✅ match itemId with ObjectId list
      { $match: { 'lines.itemId': { $in: itemObjectIds } } },

      {
        $project: {
          issNo: '$issNo',
          itemId: '$lines.itemId',
          net: {
            $subtract: [
              { $ifNull: ['$lines.issuedQty', 0] },
              {
                $add: [
                  { $ifNull: ['$lines.returnQty', 0] },
                  { $ifNull: ['$lines.scrapQty', 0] },
                ],
              },
            ],
          },
        },
      },

      // ✅ keep only positive contribution lines (optional but cleaner)
      { $match: { net: { $gt: 0 } } },

      {
        $group: {
          _id: '$itemId',
          netIssued: { $sum: '$net' },
          issueNos: { $addToSet: '$issNo' }, // ✅ collect issNo list
        },
      },

      { $match: { netIssued: { $gt: 0 } } },

      // ✅ project itemId as string for mapping
      {
        $project: {
          _id: 0,
          itemId: { $toString: '$_id' },
          netIssued: 1,
          issueNos: 1,
        },
      },
    ]);

    if (!agg.length) {
      return { ok: true, msg: 'item issue not present', categories: [] };
    }

    // ✅ IMPORTANT FIX:
    // your previous code used r._id but you projected itemId, so map was always empty
    const metaByItemId = new Map<
      string,
      { netIssued: number; issueNos: string[] }
    >(
      agg.map((r) => [
        r.itemId,
        { netIssued: r.netIssued, issueNos: r.issueNos ?? [] },
      ]),
    );

    // Keep only items that have netIssued > 0 and enrich with issueNos
    const issuedItems: IssuedItemUI[] = items
      .filter((it: any) => metaByItemId.has(it._id.toString()))
      .map((it: any) => {
        const meta = metaByItemId.get(it._id.toString())!;
        return {
          id: it._id.toString(),
          itemCode: it.itemCode ?? '',
          itemName: it.itemName ?? '',
          categoryId: it.categoryId ?? '',
          netIssued: meta.netIssued,
          issueNos: meta.issueNos, // ✅ added here (issNo list)
        };
      });

    // 5) Group items by categoryId (string)
    const itemsByCategory = new Map<string, IssuedItemUI[]>();
    for (const it of issuedItems) {
      const list = itemsByCategory.get(it.categoryId) ?? [];
      list.push(it);
      itemsByCategory.set(it.categoryId, list);
    }

    // 6) Return only categories that have at least 1 issued item
    const result: CategoryWithIssuedItems[] = categories
      .map((c: any) => {
        const cid = c._id.toString();
        const list = itemsByCategory.get(cid) ?? [];
        if (!list.length) return null;

        return {
          categoryId: cid,
          code: c.code,
          name: c.name,
          parentId: Array.isArray(c.parentId) ? c.parentId : [],
          isMachine: !!c.isMachine,
          isbag: !!c.isbag,
          isNormalItem: !!c.isNormalItem,
          items: list, // ✅ items list contains issueNos now
        };
      })
      .filter(Boolean) as CategoryWithIssuedItems[];

    return { ok: true, msg: 'item issue present', categories: result };
  }

  async disableAndAbleMachinesIfCategoryHasOutstandingIssues(
    categoryId: string,
  ) {
    const cid = (categoryId ?? '').trim();
    if (!Types.ObjectId.isValid(cid))
      throw new BadRequestException('Invalid categoryId');

    // 1) items in this category (categoryId is stored as string in StoreNewItem)
    const items = await this.itemModel
      .find({ categoryId: cid }, { _id: 1 })
      .lean();

    if (!items.length) {
      // no items => no outstanding issues => do nothing
      return { ok: true, categoryId: cid, hasOutstanding: false, updated: 0 };
    }

    const itemIds = items.map((x: any) => x._id.toString());

    // 2) compute netIssued across ALL issues for these items
    //    net = issuedQty - (returnQty + scrapQty)
    // ✅ supports lines.itemId stored as ObjectId or string (we convert to string)
    const agg = await this.issueModel.aggregate([
      { $unwind: '$lines' },
      { $addFields: { itemIdStr: { $toString: '$lines.itemId' } } },
      { $match: { itemIdStr: { $in: itemIds } } },
      {
        $group: {
          _id: null,
          totalIssued: { $sum: { $ifNull: ['$lines.issuedQty', 0] } },
          totalReturned: {
            $sum: {
              $add: [
                { $ifNull: ['$lines.returnQty', 0] },
                { $ifNull: ['$lines.scrapQty', 0] },
              ],
            },
          },
        },
      },
      {
        $project: {
          _id: 0,
          totalIssued: 1,
          totalReturned: 1,
          netIssued: { $subtract: ['$totalIssued', '$totalReturned'] },
        },
      },
    ]);

    // console.log(agg);

    const totalIssued = agg?.[0]?.totalIssued ?? 0;
    const totalReturned = agg?.[0]?.totalReturned ?? 0;
    const netIssued = agg?.[0]?.netIssued ?? 0;

    const hasOutstanding = netIssued > 0;

    if (hasOutstanding) {
      // ✅ condition not met => do nothing
      const res = await this.machineModel.updateMany(
        { categoryId: cid, isActive: false },
        { $set: { isActive: true } },
      );
      return {
        ok: true,
        categoryId: cid,
        hasOutstanding: false,
        totalIssued,
        totalReturned,
        netIssued,
        updated: 0,
      };
    } else {
      // 3) condition met => only TRUE -> FALSE
      const res = await this.machineModel.updateMany(
        { categoryId: cid, isActive: true },
        { $set: { isActive: false } },
      );

      return {
        ok: true,
        categoryId: cid,
        hasOutstanding: true,
        totalIssued,
        totalReturned,
        netIssued,
        updated: res.modifiedCount ?? 0,
      };
    }
  }
}
