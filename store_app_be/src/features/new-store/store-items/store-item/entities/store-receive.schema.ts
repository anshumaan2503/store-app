import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import mongoose, { Types } from 'mongoose';

@Schema({ _id: false })
export class StoreReceiveLine {
  @Prop()
  itemId?: String;

  @Prop()
  rackId?: String;

  @Prop({ type: Number, required: true })
  qty?: number;

  @Prop({ type: Number, default: 0 })
  unitPrice?: number;

  @Prop({ type: Number, default: 0 })
  totalPrice?: number;
}
export const StoreReceiveLineSchema =
  SchemaFactory.createForClass(StoreReceiveLine);

@Schema({ timestamps: true })
export class StoreReceive {
  @Prop({ type: String, required: true })
  receivedBy?: string;

  @Prop({ type: String, default: '' })
  remark?: string;

  @Prop({ default: '' })
  imageUrl?: string;

  @Prop({ default: '' })
  grnId?: string;

  @Prop({ default: '' })
  grnNo?: string;

  @Prop({ type: [StoreReceiveLineSchema], default: [] })
  lines?: StoreReceiveLine[];

  @Prop({ type: String, default: '' })
  recNo?: string;

  @Prop({ type: String, default: '' })
  requestId?: string;

  @Prop({ default: Date })
  createdAt?: Date;
}
export const StoreReceiveSchema = SchemaFactory.createForClass(StoreReceive);
StoreReceiveSchema.index({ requestId: 1 }, { unique: true, partialFilterExpression: { requestId: { $gt: '' } } });
StoreReceiveSchema.index({ recNo: 1 }, { unique: true, partialFilterExpression: { recNo: { $gt: '' } } });

