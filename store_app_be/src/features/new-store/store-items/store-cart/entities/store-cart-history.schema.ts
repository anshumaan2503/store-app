import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class StoreCartHistory extends Document {
  @Prop({ required: true, index: true })
  itemId: string;

  @Prop({ default: '' })
  itemName: string;

  @Prop({ default: '' })
  itemCode: string;

  @Prop({ default: 'PCS' })
  unit: string;

  @Prop({ required: true, index: true })
  userId: string;

  @Prop({ default: '' })
  userName?: string;

  @Prop({ default: 'General Operations' })
  department?: string;

  @Prop({ default: 1 })
  quantity: number;

  @Prop({ default: () => new Date() })
  addedAt: Date;

  @Prop({ default: () => new Date(), index: true })
  revertedAt: Date;

  @Prop({ default: 'AUTO_TIMEOUT_5_MIN' }) // 'AUTO_TIMEOUT_5_MIN' | 'MANUAL_REMOVED' | 'TRANSFERRED_TO_REQUESTED'
  revertType: string;

  @Prop({ default: '' })
  issNo?: string;

  @Prop({ default: '' })
  issueId?: string;

  @Prop({ default: 'Auto-revert: 5 minutes cart hold time limit exceeded' })
  remark: string;
}

export const StoreCartHistorySchema =
  SchemaFactory.createForClass(StoreCartHistory);

StoreCartHistorySchema.index({ itemId: 1, revertedAt: -1 });
