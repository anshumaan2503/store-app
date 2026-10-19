import {
  BadRequestException,
  forwardRef,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { v4 as uuid } from 'uuid';
import { minioClient } from 'src/config/minio.config';
import { StoreGrn, GrnStatus } from './schemas/store-grn.schema';
import { CreateGrnDto } from './dto/create-grn.dto';
import { StoreCartService } from '../store-cart/store-cart.service';
import { StoreCartGateway } from '../store-cart/store-cart.gateway';
import { IndentRaiseService } from '../../../stock-refill-request/stock-refill-request.service';

@Injectable()
export class StoreGrnService {
  private readonly bucketName = process.env.MINIO_BUCKET || 'auth';

  constructor(
    @InjectModel(StoreGrn.name, 'store')
    private readonly grnModel: Model<StoreGrn>,
    private readonly cartService: StoreCartService,
    private readonly cartGateway: StoreCartGateway,
    @Inject(forwardRef(() => IndentRaiseService))
    private readonly refillService: IndentRaiseService,
  ) {}

  private generateGrnNumber(): string {
    const d = new Date();
    const dateStr = d.toISOString().slice(0, 10).replace(/-/g, '');
    const rand = Math.floor(1000 + Math.random() * 9000);
    return `GRN-${dateStr}-${rand}`;
  }

  async createGrn(dto: CreateGrnDto, actorUser?: any) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('GRN must contain at least one item');
    }

    const grnNumber = this.generateGrnNumber();
    const isGrnEnabled = this.cartService.isGrnWorkflowEnabled();

    let totalQuantity = 0;
    let totalValue = 0;

    const mappedItems = dto.items.map((it) => {
      const ordQty = Math.max(0, Number(it.orderedQty || 0));
      const recQty = Math.max(0, Number(it.receivedQty || 0));
      const uPrice = Math.max(0, Number(it.unitPrice || 0));
      const tPrice = recQty * uPrice;

      totalQuantity += recQty;
      totalValue += tPrice;

      return {
        indentId: it.indentId || '',
        indentNumber: it.indentNumber || '',
        itemId: it.itemId,
        itemName: it.itemName,
        itemCode: it.itemCode || '',
        category: it.category || '',
        unit: it.unit || '',
        orderedQty: ordQty,
        receivedQty: recQty,
        unitPrice: uPrice,
        totalPrice: tPrice,
        isPutawayComplete: false,
        putawayQty: 0,
      };
    });

    const actor = {
      uid: actorUser?.uid || dto.submittedBy?.uid || '',
      name: actorUser?.name || dto.submittedBy?.name || 'Store Operator',
      email: actorUser?.email || dto.submittedBy?.email || '',
    };

    const initialStatus: GrnStatus = isGrnEnabled ? 'PENDING_APPROVAL' : 'APPROVED';

    const timeline = [
      {
        action: 'GRN_SUBMITTED',
        title: 'GRN Created & Submitted',
        description: `GRN ${grnNumber} submitted with ${mappedItems.length} items (Total: ₹${totalValue.toFixed(2)}). Status: ${initialStatus}`,
        actorName: actor.name,
        timestamp: new Date(),
      },
    ];

    if (!isGrnEnabled) {
      timeline.push({
        action: 'GRN_AUTO_APPROVED',
        title: 'Auto-Approved',
        description: 'GRN auto-approved as GRN workflow approval toggle is disabled.',
        actorName: 'System',
        timestamp: new Date(),
      });
    }

    const grnDoc = await this.grnModel.create({
      grnNumber,
      status: initialStatus,
      imageUrl: dto.imageUrl || '',
      remarks: dto.remarks || '',
      items: mappedItems,
      totalItems: mappedItems.length,
      totalQuantity,
      totalValue,
      submittedBy: actor,
      timeline,
      approvedBy: !isGrnEnabled ? { uid: 'system', name: 'Auto System' } : undefined,
      approvedAt: !isGrnEnabled ? new Date() : undefined,
    });

    // Update timeline on all associated indents
    for (const it of mappedItems) {
      if (it.indentId) {
        try {
          await this.refillService.pushTimelineEvent(it.indentId, {
            action: 'ADDED_TO_GRN',
            title: `Added to GRN ${grnNumber}`,
            description: `Physical verification completed. Ordered: ${it.orderedQty}, Verified: ${it.receivedQty} @ ₹${it.unitPrice}/pc. Status: ${initialStatus}`,
            actorName: actor.name,
          });
        } catch (_) {}
      }
    }

    if (this.cartGateway?.server) {
      this.cartGateway.server.emit('store:grn:created', grnDoc);
    }

    return grnDoc;
  }

  async listGrn(query: {
    status?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Math.max(1, Number(query.page || 1));
    const limit = Math.min(100, Math.max(1, Number(query.limit || 20)));
    const skip = (page - 1) * limit;

    const filter: any = {};
    if (query.status && query.status !== 'ALL') {
      filter.status = query.status;
    }

    if (query.search && query.search.trim()) {
      const q = query.search.trim();
      filter.$or = [
        { grnNumber: { $regex: q, $options: 'i' } },
        { 'items.itemName': { $regex: q, $options: 'i' } },
        { remarks: { $regex: q, $options: 'i' } },
      ];
    }

    const [rows, total] = await Promise.all([
      this.grnModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean().exec(),
      this.grnModel.countDocuments(filter).exec(),
    ]);

    return {
      status: true,
      data: rows,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getGrnById(id: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid GRN ID');
    }
    const doc = await this.grnModel.findById(id).lean().exec();
    if (!doc) throw new NotFoundException('GRN not found');
    return doc;
  }

  async approveGrn(id: string, approverUser: any) {
    const grn = await this.grnModel.findById(id);
    if (!grn) throw new NotFoundException('GRN not found');

    if (grn.status !== 'PENDING_APPROVAL') {
      throw new BadRequestException(`Cannot approve GRN in status ${grn.status}`);
    }

    const approver = {
      uid: approverUser?.uid || '',
      name: approverUser?.name || approverUser?.email || 'Approver',
      email: approverUser?.email || '',
    };

    grn.status = 'APPROVED';
    grn.approvedBy = approver;
    grn.approvedAt = new Date();

    grn.timeline.push({
      action: 'GRN_APPROVED',
      title: 'GRN Approved',
      description: `GRN approved by ${approver.name}. Items are now unlocked for QR scan and rack putaway.`,
      actorName: approver.name,
      timestamp: new Date(),
    });

    await grn.save();

    // Push timeline to each indent
    for (const it of grn.items) {
      if (it.indentId) {
        try {
          await this.refillService.pushTimelineEvent(it.indentId, {
            action: 'GRN_APPROVED',
            title: `GRN ${grn.grnNumber} Approved`,
            description: `Approved by ${approver.name}. Item ready for QR rack putaway.`,
            actorName: approver.name,
          });
        } catch (_) {}
      }
    }

    if (this.cartGateway?.server) {
      this.cartGateway.server.emit('store:grn:approved', grn);
    }

    return grn;
  }

  async rejectGrn(id: string, reason: string, rejectorUser: any) {
    const grn = await this.grnModel.findById(id);
    if (!grn) throw new NotFoundException('GRN not found');

    if (grn.status !== 'PENDING_APPROVAL') {
      throw new BadRequestException(`Cannot reject GRN in status ${grn.status}`);
    }

    const rejector = {
      uid: rejectorUser?.uid || '',
      name: rejectorUser?.name || rejectorUser?.email || 'Approver',
      email: rejectorUser?.email || '',
    };

    grn.status = 'REJECTED';
    grn.rejectedBy = rejector;
    grn.rejectedAt = new Date();
    grn.rejectionReason = reason || 'No reason provided';

    grn.timeline.push({
      action: 'GRN_REJECTED',
      title: 'GRN Rejected',
      description: `Rejected by ${rejector.name}. Reason: ${grn.rejectionReason}`,
      actorName: rejector.name,
      timestamp: new Date(),
    });

    await grn.save();

    // Push timeline to each indent
    for (const it of grn.items) {
      if (it.indentId) {
        try {
          await this.refillService.pushTimelineEvent(it.indentId, {
            action: 'GRN_REJECTED',
            title: `GRN ${grn.grnNumber} Rejected`,
            description: `GRN rejected by ${rejector.name}. Reason: ${grn.rejectionReason}`,
            actorName: rejector.name,
          });
        } catch (_) {}
      }
    }

    if (this.cartGateway?.server) {
      this.cartGateway.server.emit('store:grn:rejected', grn);
    }

    return grn;
  }

  async getActiveApprovedGrnForItem(itemId: string) {
    if (!itemId) return null;
    const doc = await this.grnModel
      .findOne({
        status: 'APPROVED',
        'items.itemId': itemId,
        'items.isPutawayComplete': false,
      })
      .sort({ createdAt: -1 })
      .lean()
      .exec();

    if (!doc) return null;

    const matchedItem = doc.items.find(
      (it) => it.itemId === itemId && !it.isPutawayComplete,
    );

    return {
      grnId: String(doc._id),
      grnNumber: doc.grnNumber,
      imageUrl: doc.imageUrl,
      item: matchedItem,
    };
  }

  async markItemPutaway(grnId: string, itemId: string, receivedQty: number) {
    if (!grnId || !itemId) return;
    try {
      const grn = await this.grnModel.findById(grnId);
      if (!grn) return;

      let allDone = true;
      for (const it of grn.items) {
        if (it.itemId === itemId) {
          it.putawayQty = (it.putawayQty || 0) + receivedQty;
          if (it.putawayQty >= it.receivedQty) {
            it.isPutawayComplete = true;
          }
        }
        if (!it.isPutawayComplete) {
          allDone = false;
        }
      }

      if (allDone) {
        grn.status = 'RECEIVED';
        grn.timeline.push({
          action: 'GRN_ALL_PUTAWAY_COMPLETE',
          title: 'All Items Putaway Complete',
          description: `All ${grn.items.length} items putaway into store racks successfully.`,
          actorName: 'System',
          timestamp: new Date(),
        });
      }

      grn.markModified('items');
      grn.markModified('timeline');
      await grn.save();
    } catch (err) {
      console.error('[StoreGrnService] markItemPutaway error:', err);
    }
  }

  async uploadGrnImageBase64(base64Data: string): Promise<string> {
    if (!base64Data) throw new BadRequestException('Missing image data');

    const mimeMatch = base64Data.match(/^data:(image\/\w+);base64,/);
    const mime = mimeMatch ? mimeMatch[1] : 'image/jpeg';
    const raw = base64Data.replace(/^data:image\/\w+;base64,/, '').replace(/\s/g, '');
    const buffer = Buffer.from(raw, 'base64');
    const ext = mime.includes('webp') ? '.webp' : mime.includes('png') ? '.png' : '.jpg';
    const key = `store-grn/${uuid()}${ext}`;

    await minioClient.putObject(this.bucketName, key, buffer, {
      'Content-Type': mime,
    });

    return `https://minioimg.rrispat.in/${this.bucketName}/${key}`;
  }
}
