import { BadRequestException, Injectable } from '@nestjs/common';
import {
  CreateStoreScrapDto,
  ScrapPagedQueryDto,
  UpdateStoreScrapDto,
} from './dto/create-store-scrap.dto';
import { StoreItemScrap } from './entities/store-scrap.schema';
import { ClientSession, FilterQuery, Model, SortOrder, Types } from 'mongoose';
import { InjectModel } from '@nestjs/mongoose';
import { UserService } from 'src/features/user/user.service';
import { Rack } from '../../locations/rack/entities/rack.schema';
import { StoreNewItem } from '../store-item/entities/store-item.schema';
import {
  ItemRackQty,
  ItemRackQtyDocument,
} from '../../locations/rack/entities/item-rack-qty.schema';
import {
  StockTrack,
  StockTrackDocument,
  StockTrackType,
} from '../store-item/entities/stock-track.schema';

@Injectable()
export class StoreScrapService {
  constructor(
    @InjectModel(StoreItemScrap.name, 'store')
    private readonly model: Model<StoreItemScrap>,

    @InjectModel(Rack.name, 'store')
    private readonly rackModel: Model<Rack>,

    @InjectModel(StoreNewItem.name, 'store')
    private readonly itemModel: Model<StoreNewItem>,

    @InjectModel(ItemRackQty.name, 'store')
    private readonly itemRackQtyModel: Model<ItemRackQtyDocument>,

    @InjectModel(StockTrack.name, 'store')
    private readonly trackModel: Model<StockTrackDocument>,

    private readonly userService: UserService,
  ) {}

  private async track(
    // session: ClientSession,///////
    input: {
      type: StockTrackType;
      qty: number;
      operatedBy: string;

      itemId?: string;
      categoryId?: string;
      rackId?: string;

      receivingId?: string;
      issueId?: string;

      refNo?: string;
      note?: string;
    },
  ) {
    await this.trackModel.create(
      [
        {
          type: input.type,
          qty: Number(input.qty || 0),

          refNo: input.refNo ?? '',
          note: input.note ?? '',

          operatedBy: input.operatedBy,

          itemId: input.itemId ?? null,
          categoryId: input.categoryId ?? null,
          rackId: input.rackId ?? null,

          receivingId: input.receivingId ?? null,
          issueId: input.issueId ?? null,
        },
      ],
      // { session },
    );
  }

  private oid(id: string) {
    if (!id || !Types.ObjectId.isValid(id)) {
      throw new BadRequestException(`Invalid ObjectId: ${id}`);
    }
    return new Types.ObjectId(id);
  }
  private oidOrNull(id?: string | null) {
    const v = String(id ?? '').trim();
    return v && Types.ObjectId.isValid(v) ? new Types.ObjectId(v) : null;
  }
  private sortObj(sort?: string): Record<string, SortOrder> {
    const s = (sort || '-createdAt').trim();
    const desc = s.startsWith('-');
    const field = (desc ? s.slice(1) : s) || 'createdAt';
    return { [field]: (desc ? -1 : 1) as SortOrder } as Record<
      string,
      SortOrder
    >;
  }

  private mustOperatorId(id?: string | null, label = 'operatedBy') {
    const op = this.oidOrNull(id);
    if (!op) throw new BadRequestException(`${label} missing/invalid`);
    return op;
  }
  // create(createStoreScrapDto: CreateStoreScrapDto) {
  //   return 'This action adds a new storeScrap';
  // }

  private readonly inflightScraps = new Set<string>();

  async create(dto: CreateStoreScrapDto) {
    const itemId = String(dto.itemId || '').trim();
    const qty = Number(dto.itemQuantity || 0);
    const createdBy = String(dto.createdBy || '').trim();
    const rackId = String(dto.rackId || '').trim();

    if (!itemId) throw new BadRequestException('itemId required');
    if (!createdBy) throw new BadRequestException('receivedBy required');
    if (!rackId) throw new BadRequestException('rackId required');
    if (!Number.isFinite(qty) || qty <= 0)
      throw new BadRequestException('qty must be > 0');

    const operatedBy = this.mustOperatorId(createdBy, 'createdBy');

    const lockKey = dto.requestId;
    if (lockKey) {
      if (this.inflightScraps.has(lockKey)) {
        return { status: true, duplicate: true, msg: 'Scrap operation already in progress' };
      }
      this.inflightScraps.add(lockKey);

      const existingDoc = await this.model.findOne({ requestId: lockKey }).lean();
      if (existingDoc) {
        this.inflightScraps.delete(lockKey);
        return { status: true, duplicate: true, msg: 'Scrap operation already completed', id: String(existingDoc._id) };
      }
    }

    // 1. Validation & Pre-fetch
    const item = await this.itemModel.findById(this.oid(itemId));
    if (!item) throw new BadRequestException('Item not found');

    const rack = await this.rackModel.findById(this.oid(rackId));
    if (!rack) throw new BadRequestException('rack not found');

    const user = await this.userService.findById(createdBy);
    if (!user) throw new BadRequestException('createdBy not found');

    const checkrack = await this.itemRackQtyModel.findOne({
      rackId: rackId,
      itemId: itemId,
    });
    if (!checkrack) {
      throw new BadRequestException('No inventory record found for this rack');
    }

    // Availability validation guards (TASK-STORE-907 / SCRAP-RISK-003)
    if ((checkrack.stockAvailableQuantity ?? 0) < qty) {
      throw new BadRequestException('Scrap quantity exceeds available stock');
    }
    if ((item.stockAvailableQuantity ?? 0) < qty) {
      throw new BadRequestException('Scrap quantity exceeds available stock');
    }

    let session: ClientSession | null = null;
    try {
      session = await this.itemModel.db.startSession();
      await session.withTransaction(async () => {
        await this.executeScrapOperations(
          item,
          rack,
          user,
          checkrack,
          qty,
          dto.remark,
          operatedBy,
          session,
          lockKey,
        );
      });
      return { status: true, msg: 'Scrap operation completed' };
    } catch (err: any) {
      if (err?.code === 11000 || err?.message?.includes('E11000')) {
        const existingDoc = await this.model.findOne({ requestId: lockKey }).lean();
        return { status: true, duplicate: true, msg: 'Scrap operation already completed', id: existingDoc ? String(existingDoc._id) : '' };
      }
      if (
        err?.message?.includes('replica set') ||
        err?.code === 20 ||
        err?.codeName === 'IllegalOperation'
      ) {
        // Fallback for standalone MongoDB
        try {
          await this.executeScrapWithCompensation(
            item,
            rack,
            user,
            checkrack,
            qty,
            dto.remark,
            operatedBy,
            lockKey,
          );
          return { status: true, msg: 'Scrap operation completed' };
        } catch (compErr: any) {
          if (compErr?.code === 11000 || compErr?.message?.includes('E11000')) {
            const existingDoc = await this.model.findOne({ requestId: lockKey }).lean();
            return { status: true, duplicate: true, msg: 'Scrap operation already completed', id: existingDoc ? String(existingDoc._id) : '' };
          }
          throw compErr;
        }
      }
      throw err;
    } finally {
      if (lockKey) {
        this.inflightScraps.delete(lockKey);
      }
      if (session) {
        await session.endSession();
      }
    }

  }

  private async executeScrapOperations(
    item: any,
    rack: any,
    user: any,
    checkrack: any,
    qty: number,
    remark?: string,
    operatedBy?: Types.ObjectId,
    session?: ClientSession | null,
    requestId?: string,
  ) {
    // 1) Update global item usable/scrap quantities (TASK-STORE-906 / SCRAP-RISK-001)
    await this.itemModel.updateOne(
      { _id: item._id },
      {
        $inc: {
          stockAvailableQuantity: -qty,
          stockscrapQuantity: qty,
        },
      },
      { session: session || undefined },
    );

    // 2) Update rack item usable/scrap quantities
    await this.itemRackQtyModel.findByIdAndUpdate(
      checkrack._id,
      {
        $inc: {
          stockAvailableQuantity: -qty,
          stockscrapQuantity: qty,
        },
      },
      { session: session || undefined },
    );

    // 3) Create scrap receipt document
    const createdByName = String(user.name || '').trim();
    const now = new Date();
    const updatedDate = new Date(now.getTime() + 330 * 60 * 1000);
    const receipt = await this.model.create(
      [
        {
          createdBy: String(user._id || user.id),
          createdByName,
          remark: remark ?? '',
          requestId: requestId ?? '',
          itemId: String(item._id),
          itemName: item.itemName,
          itemCode: item.itemCode,
          rackId: String(rack._id),
          rackCode: rack.code,
          roomId: rack.roomId,
          roomCode: rack.roomName,
          itemQuantity: qty,
          createdAt: updatedDate,
        },
      ],
      { session: session || undefined },
    );
    const receivingDoc = receipt?.[0];

    // 4) Create StockTrack audit log (TASK-STORE-908 / SCRAP-RISK-002)
    await this.trackModel.create(
      [
        {
          type: 'SCRAP',
          qty: -qty, // Usable stock reduction
          operatedBy: String(operatedBy),
          itemId: String(item._id),
          categoryId: item.categoryId ?? '',
          rackId: String(rack._id),
          receivingId: String(receivingDoc?._id) ?? '',
          refNo: receivingDoc ? String(receivingDoc._id) : '',
          note: `Scrap: ${qty} units moved to scrap`,
        },
      ],
      { session: session || undefined },
    );
  }

  private async executeScrapWithCompensation(
    item: any,
    rack: any,
    user: any,
    checkrack: any,
    qty: number,
    remark?: string,
    operatedBy?: Types.ObjectId,
    requestId?: string,
  ) {
    let globalUpdated = false;
    let rackUpdated = false;
    let receiptDoc: any = null;

    try {
      // 1) Update global item stock
      await this.itemModel.updateOne(
        { _id: item._id },
        {
          $inc: {
            stockAvailableQuantity: -qty,
            stockscrapQuantity: qty,
          },
        },
      );
      globalUpdated = true;

      // 2) Update rack item stock
      await this.itemRackQtyModel.findByIdAndUpdate(checkrack._id, {
        $inc: {
          stockAvailableQuantity: -qty,
          stockscrapQuantity: qty,
        },
      });
      rackUpdated = true;

      // 3) Create scrap receipt document
      const createdByName = String(user.name || '').trim();
      const now = new Date();
      const updatedDate = new Date(now.getTime() + 330 * 60 * 1000);
      const receipt = await this.model.create([
        {
          createdBy: String(user._id || user.id),
          createdByName,
          remark: remark ?? '',
          requestId: requestId ?? '',
          itemId: String(item._id),
          itemName: item.itemName,
          itemCode: item.itemCode,
          rackId: String(rack._id),
          rackCode: rack.code,
          roomId: rack.roomId,
          roomCode: rack.roomName,
          itemQuantity: qty,
          createdAt: updatedDate,
        },
      ]);

      receiptDoc = receipt?.[0];

      // 4) Create StockTrack audit log
      await this.trackModel.create([
        {
          type: 'SCRAP',
          qty: -qty,
          operatedBy: String(operatedBy),
          itemId: String(item._id),
          categoryId: item.categoryId ?? '',
          rackId: String(rack._id),
          receivingId: String(receiptDoc?._id) ?? '',
          refNo: receiptDoc ? String(receiptDoc._id) : '',
          note: `Scrap: ${qty} units moved to scrap`,
        },
      ]);
    } catch (err) {
      // Compensate on failure
      if (receiptDoc?._id) {
        await this.model.deleteOne({ _id: receiptDoc._id }).catch(() => {});
      }
      if (rackUpdated) {
        await this.itemRackQtyModel
          .findByIdAndUpdate(checkrack._id, {
            $inc: {
              stockAvailableQuantity: qty,
              stockscrapQuantity: -qty,
            },
          })
          .catch(() => {});
      }
      if (globalUpdated) {
        await this.itemModel
          .updateOne(
            { _id: item._id },
            {
              $inc: {
                stockAvailableQuantity: qty,
                stockscrapQuantity: -qty,
              },
            },
          )
          .catch(() => {});
      }
      throw err;
    }
  }

  findAll() {
    return `This action returns all storeScrap`;
  }

  async findAllScrapPaged(q: ScrapPagedQueryDto) {
    const page = Math.max(1, Number(q.page || 1));
    const limit = Math.min(200, Math.max(1, Number(q.limit || 12)));
    const skip = (page - 1) * limit;

    const filter: FilterQuery<StoreItemScrap> = {};

    const search = (q.search || '').trim();

    var datatotal = await this.model.find();

    var data = await this.model
      .find()
      .sort(this.sortObj(q.sort))
      .skip(skip)
      .limit(limit)
      .lean();

    return { rows: data, datatotal, page, limit };
  }

  findOne(id: number) {
    return `This action returns a #${id} storeScrap`;
  }

  update(id: number, updateStoreScrapDto: UpdateStoreScrapDto) {
    return `This action updates a #${id} storeScrap`;
  }

  remove(id: number) {
    return `This action removes a #${id} storeScrap`;
  }
}
