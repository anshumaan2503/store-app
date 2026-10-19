// item-issue.schema.ts
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

class IssueLine {
  @Prop()
  itemId!: string;

  @Prop({ required: true, trim: true })
  itemName!: string;

  @Prop({ required: true, min: 1 })
  requestedQty!: number;

  @Prop({ default: 0, min: 0 })
  approvedQty: number;

  @Prop({ default: 0, min: 0 })
  issuedQty: number;

  // ✅ Good items returned back to stock
  @Prop({ default: 0, min: 0 })
  returnQty: number;

  // ✅ Scrap items (NOT returned to stock)
  @Prop({ default: 0, min: 0 })
  scrapQty: number;

  @Prop({ default: 0, min: 0 })
  approvedRejectQty: number;

  @Prop({ default: 0, min: 0 })
  issuedRejectQty: number;

  @Prop({ default: '' })
  unit: string;

  @Prop({ type: Number, default: 0 })
  unitPrice?: number;

  @Prop({ type: Number, default: 0 })
  totalPrice?: number;

  @Prop({
    type: [
      {
        lotId: { type: String, default: '' },
        qty: { type: Number, default: 0 },
        unitPrice: { type: Number, default: 0 },
      },
    ],
    default: [],
  })
  consumedLots?: Array<{
    lotId: string;
    qty: number;
    unitPrice: number;
  }>;
}

class IssueAllocation {
  @Prop()
  itemId: String;

  @Prop({ required: true, trim: true })
  itemName: string;

  @Prop()
  rackId: string;

  @Prop({ required: true, trim: true })
  rackName: string;

  @Prop({ required: true, min: 1 })
  qty: number;

  @Prop({ type: Number, default: 0 })
  unitPrice?: number;

  @Prop({ type: Number, default: 0 })
  totalPrice?: number;

  // total returned (good+scrap) mapped FIFO from allocations
  @Prop({ default: 0, min: 0 })
  returnedQty: number;

  // optional split
  @Prop({ default: 0, min: 0 })
  returnedGoodQty: number;

  @Prop({ default: 0, min: 0 })
  returnedScrapQty: number;

  @Prop({ default: Date.now })
  issuedAt: Date;

  @Prop({ default: "" })
  issuedBy: string;
}

@Schema({ timestamps: true, versionKey: false })
export class ItemIssue {
  @Prop({ required: true,  })
  issNo: string;

  @Prop({ default: '' })
  reason: string;

  @Prop({ default: '' })
  remark: string;

  @Prop({ type: [IssueLine], default: [] })
  lines: IssueLine[];

  @Prop({
    default: 'DRAFT',
  })
  status?: string;

  @Prop()
  expiresAt?: Date;

  @Prop({ default: '' })
  departmentName?: string;

  @Prop({ default: '' })
  divisionName?: string;

  @Prop()
  createdBy: string;

  @Prop()
  approvedBy?: string;

  @Prop()
  approvedAt?: Date;

  @Prop()
  rejectedBy?: string;

  @Prop()
  rejectedAt?: Date;

  @Prop()
  closedBy?: string;

  @Prop()
  closedAt?: Date;

  @Prop({ type: [IssueAllocation], default: [] })
  allocations: IssueAllocation[];

  @Prop({ default: '' })
  requestId?: string;

  @Prop()
  revertedBy?: string;

  @Prop()
  revertedAt?: Date;

  @Prop({ default: '' })
  revertReason?: string;

  createdAt?: Date;
  updatedAt?: Date;
}

export type ItemIssueDocument = HydratedDocument<ItemIssue>;
export const ItemIssueSchema = SchemaFactory.createForClass(ItemIssue);
ItemIssueSchema.index({ issNo: 1 }, { unique: true, partialFilterExpression: { issNo: { $gt: '' } } });
ItemIssueSchema.index({ requestId: 1 }, { unique: true, partialFilterExpression: { requestId: { $gt: '' } } });

