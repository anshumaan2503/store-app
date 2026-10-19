import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class StoreCartItemDoc {
  @Prop({ required: true })
  id: string;

  @Prop({ default: '' })
  itemName: string;

  @Prop({ default: '' })
  itemCode: string;

  @Prop({ default: 'PCS' })
  unit: string;

  @Prop({ default: '' })
  imageUrl: string;

  @Prop({ default: 1 })
  quantity: number;

  @Prop({ default: 0 })
  stockAvailableQuantity: number;

  @Prop({ default: null })
  rackId?: string;

  @Prop({ default: null })
  categoryId?: string;

  @Prop({ default: null })
  categoryLabel?: string;

  @Prop({ default: () => new Date() })
  addedAt: Date;
}

export const StoreCartItemSchema =
  SchemaFactory.createForClass(StoreCartItemDoc);

@Schema({ timestamps: true })
export class StoreCart extends Document {
  @Prop({ required: true, unique: true, index: true })
  userId: string;

  @Prop({ type: [StoreCartItemSchema], default: [] })
  items: StoreCartItemDoc[];
}

export const StoreCartSchema = SchemaFactory.createForClass(StoreCart);
