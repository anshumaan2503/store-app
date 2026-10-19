// stock-stock-track.schema.ts
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type StockTrackType =
  | 'CREATE'
  | 'EDIT'
  | 'APPROVED'
  | 'APPROVAL_REVERTED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'RECEIVE'
  | 'ISSUE'
  | 'RETURN'
  | 'SCRAP'
  | 'ADJUST'
  | 'CLOSED';

export type StockTrackDocument = HydratedDocument<StockTrack>;

@Schema({ timestamps: true, versionKey: false })
export class StockTrack {
  @Prop({ default: '' })
  itemId?: string;

  @Prop({ default: '' })
  categoryId?: string;

  @Prop({ default: '' })
  rackId?: string;

  @Prop({ default: '' })
  receivingId?: string;

  @Prop({ default: '' })
  issueId?: string;

  @Prop({
    required: true,
    enum: [
      'CREATE',
      'EDIT',
      'APPROVED',
      'APPROVAL_REVERTED',
      'REJECTED',
      'CANCELLED',
      'RECEIVE',
      'ISSUE',
      'RETURN',
      'SCRAP',
      'ADJUST',
      'CLOSED',
    ],
    index: true,
  })
  type?: StockTrackType;

  // + for receive/return/adjust up, - for issue/scrap/adjust down, 0 for workflow events
  @Prop({ required: true })
  qty?: number;

  @Prop({ default: '' })
  refNo?: string;

  @Prop({ default: '' })
  operatedBy?: string;

  @Prop({ default: '' })
  note?: string;

  @Prop({ type: Number, default: 0 })
  unitPrice?: number;

  @Prop({ type: Number, default: 0 })
  totalPrice?: number;

  @Prop({ default: '' })
  lotId?: string;
}

export const StockTrackSchema = SchemaFactory.createForClass(StockTrack);


