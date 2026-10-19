import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true, _id: false })
export class IndentDraftItem {
  @Prop({ required: true })
  itemId: string;

  @Prop({ default: '' })
  itemName: string;

  @Prop({ default: '' })
  itemCode: string;

  @Prop({ default: 'PCS' })
  unit: string;

  @Prop({ default: '' })
  imageUrl: string;

  @Prop({ default: 1, min: 1 })
  quantity: number;

  @Prop({ default: '' })
  reason?: string;

  @Prop({ default: () => new Date() })
  addedAt: Date;
}

export const IndentDraftItemSchema =
  SchemaFactory.createForClass(IndentDraftItem);

export type IndentDraftDocument = IndentDraft & Document;

@Schema({ collection: 'indentdrafts', timestamps: true, versionKey: false })
export class IndentDraft {
  @Prop({ required: true, unique: true, index: true })
  userId: string;

  @Prop({ type: [IndentDraftItemSchema], default: [] })
  items: IndentDraftItem[];
}

export const IndentDraftSchema = SchemaFactory.createForClass(IndentDraft);
