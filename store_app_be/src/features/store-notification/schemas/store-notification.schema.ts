import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import mongoose, { Document, Types } from 'mongoose';

export type StoreNotificationDocument = StoreNotification & Document;

@Schema({ timestamps: true, versionKey: false })
export class StoreNotification {
  @Prop({ required: true, index: true })
  userId: string;

  @Prop({
    type: mongoose.Schema.Types.ObjectId,
    ref: 'StoreNewItem',
    required: true,
    index: true,
  })
  itemId: Types.ObjectId;

  @Prop({ required: true, default: 'LOW_STOCK', index: true })
  type: string;

  @Prop({ required: true, default: 'Stock running low' })
  title: string;

  @Prop({ required: true, default: '' })
  message: string;

  @Prop({ default: '' })
  itemName: string;

  @Prop({ default: '' })
  itemCode: string;

  @Prop({ default: '' })
  unit: string;

  @Prop({ default: 0 })
  availableQuantity: number;

  @Prop({ default: 0 })
  totalQuantity: number;

  @Prop({ default: false, index: true })
  isRead: boolean;

  @Prop()
  readAt?: Date;

  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ default: false, index: true })
  isDismissed: boolean;
}

export const StoreNotificationSchema =
  SchemaFactory.createForClass(StoreNotification);

StoreNotificationSchema.index({ userId: 1, itemId: 1, type: 1 }, { unique: true });
