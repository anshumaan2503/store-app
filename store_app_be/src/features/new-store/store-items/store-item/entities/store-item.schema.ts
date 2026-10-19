import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import mongoose, { Document } from 'mongoose';

@Schema({ timestamps: true })
export class StoreNewItem extends Document {
  @Prop({ default: '' })
  itemCode?: string;

  @Prop({ default: '' })
  itemName?: string;

  // Field 2: Rack
  @Prop({ default: [] })
  rackId?: string[];

  // Field 3: Category/Subcategory (same collection; may point to category or subcategory)
  @Prop({ default: '' })
  categoryId?: string;

  @Prop({ default: '' })
  categoryLabel?: string; // "Category > Subcategory" or "Category"

  // Field 4:
  @Prop({ default: '' })
  unit?: string;

  @Prop({ default: '' })
  unitId?: string;

  // Field 5:
  @Prop({ default: '' })
  description?: string;

  @Prop({ default: 0 })
  isScrap?: boolean;

  @Prop({ default: 0 })
  maxCapacity?: number;

  @Prop({ default: 0 })
  maxQuantity?: number;

  // Minimum stock threshold for automated refill indent generation
  @Prop({ type: Number, min: 0, default: 0 })
  minStockQuantity?: number;

  @Prop({ type: Boolean, default: false, index: true })
  isIndentReady?: boolean;

  @Prop({ type: Number, min: 0, default: 0 })
  defaultRefillQuantity?: number;

  // Extra fields
  @Prop({ type: Number, required: true, min: 0, default: 0 })
  totalStockQuantity?: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  stockAvailableQuantity?: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  stockRequestedQuantity?: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  stockIssueQuantity?: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  stockissueCompleted?: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  stockscrapQuantity?: number;

  @Prop({ default: '' })
  imageUrl?: string;

  @Prop({ default: '' })
  createdBy?: string;

  @Prop({ type: Number, default: 0 })
  latestPurchasePrice?: number;

  @Prop({
    type: [
      {
        lotId: { type: String, required: true },
        qty: { type: Number, required: true, default: 0 },
        remainingQty: { type: Number, required: true, default: 0 },
        unitPrice: { type: Number, required: true, default: 0 },
        receivedAt: { type: Date, default: Date.now },
        recNo: { type: String, default: '' },
        grnNo: { type: String, default: '' },
      },
    ],
    default: [],
  })
  stockLots?: Array<{
    lotId: string;
    qty: number;
    remainingQty: number;
    unitPrice: number;
    receivedAt: Date;
    recNo?: string;
    grnNo?: string;
  }>;
}

export const StoreNewItemSchema = SchemaFactory.createForClass(StoreNewItem);
