import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class StoreCartConfig extends Document {
  @Prop({ default: 'default_cart_config', unique: true, index: true })
  configKey: string;

  // Cart Hold Timeout (Minutes)
  @Prop({ default: 5 })
  cartTimeoutMinutes: number;

  @Prop({ default: true })
  cartTimeoutEnabled: boolean;

  // Requisition / Requested Item Timeout (Days)
  @Prop({ default: 7 })
  requestTimeoutDays: number;

  @Prop({ default: true })
  requestTimeoutEnabled: boolean;

  // Month-End Auto-Revert for uncollected Ready-for-Issue items
  @Prop({ default: true })
  monthEndRevertEnabled: boolean;

  @Prop({ default: 30 })
  monthEndRevertDays: number;

  // Indent Approval Switch: Require approval before indents appear in Receive
  @Prop({ default: false })
  indentApprovalRequired: boolean;

  // GRN Workflow Switch: Require GRN Cart inspection & approval before QR scan putaway
  @Prop({ default: false })
  grnWorkflowEnabled: boolean;

  // Auto-close stale indents after 1 month (30 days default)
  @Prop({ default: 30 })
  indentAutoCloseDays: number;

  @Prop({ default: true })
  indentAutoCloseEnabled: boolean;

  @Prop({ default: null })
  updatedBy?: string;
}

export const StoreCartConfigSchema =
  SchemaFactory.createForClass(StoreCartConfig);
