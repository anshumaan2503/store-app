import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type GrnStatus = 'PENDING_APPROVAL' | 'APPROVED' | 'REJECTED' | 'RECEIVED';

@Schema({ _id: false })
export class GrnItem {
  @Prop({ default: '' })
  indentId?: string;

  @Prop({ default: '' })
  indentNumber?: string;

  @Prop({ required: true })
  itemId: string;

  @Prop({ required: true, default: '' })
  itemName: string;

  @Prop({ default: '' })
  itemCode?: string;

  @Prop({ default: '' })
  category?: string;

  @Prop({ default: '' })
  unit?: string;

  @Prop({ type: Number, required: true, default: 0 })
  orderedQty: number;

  @Prop({ type: Number, required: true, default: 0 })
  receivedQty: number;

  @Prop({ type: Number, required: true, default: 0 })
  unitPrice: number;

  @Prop({ type: Number, required: true, default: 0 })
  totalPrice: number;

  @Prop({ type: Boolean, default: false })
  isPutawayComplete: boolean;

  @Prop({ type: Number, default: 0 })
  putawayQty: number;
}
export const GrnItemSchema = SchemaFactory.createForClass(GrnItem);

@Schema({ _id: false })
export class GrnTimelineEvent {
  @Prop({ required: true })
  action: string;

  @Prop({ required: true })
  title: string;

  @Prop({ default: '' })
  description: string;

  @Prop({ default: 'System' })
  actorName: string;

  @Prop({ default: Date.now })
  timestamp: Date;
}
export const GrnTimelineEventSchema = SchemaFactory.createForClass(GrnTimelineEvent);

@Schema({ _id: false })
export class GrnActor {
  @Prop({ default: '' })
  uid: string;

  @Prop({ default: '' })
  name: string;

  @Prop({ default: '' })
  email?: string;
}
export const GrnActorSchema = SchemaFactory.createForClass(GrnActor);

@Schema({ timestamps: true })
export class StoreGrn extends Document {
  @Prop({ required: true, unique: true, index: true })
  grnNumber: string;

  @Prop({
    type: String,
    enum: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'RECEIVED'],
    default: 'PENDING_APPROVAL',
    index: true,
  })
  status: GrnStatus;

  @Prop({ default: '' })
  imageUrl: string;

  @Prop({ default: '' })
  remarks?: string;

  @Prop({ type: [GrnItemSchema], default: [] })
  items: GrnItem[];

  @Prop({ type: Number, default: 0 })
  totalItems: number;

  @Prop({ type: Number, default: 0 })
  totalQuantity: number;

  @Prop({ type: Number, default: 0 })
  totalValue: number;

  @Prop({ type: GrnActorSchema })
  submittedBy?: GrnActor;

  @Prop({ type: GrnActorSchema })
  approvedBy?: GrnActor;

  @Prop()
  approvedAt?: Date;

  @Prop({ type: GrnActorSchema })
  rejectedBy?: GrnActor;

  @Prop()
  rejectedAt?: Date;

  @Prop({ default: '' })
  rejectionReason?: string;

  @Prop({ type: [GrnTimelineEventSchema], default: [] })
  timeline: GrnTimelineEvent[];

  @Prop({ default: Date.now })
  createdAt: Date;

  @Prop({ default: Date.now })
  updatedAt: Date;
}

export const StoreGrnSchema = SchemaFactory.createForClass(StoreGrn);
StoreGrnSchema.index({ status: 1, createdAt: -1 });
StoreGrnSchema.index({ 'items.itemId': 1 });
