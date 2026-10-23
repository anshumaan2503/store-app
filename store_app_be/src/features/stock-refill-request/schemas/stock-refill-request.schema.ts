import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import mongoose, { Document, Types } from 'mongoose';

export type IndentRaiseDocument = IndentRaise & Document;
export type StockRefillRequestDocument = IndentRaiseDocument;

@Schema({
  collection: 'stockrefillrequests',
  timestamps: true,
  versionKey: false,
  toJSON: { virtuals: true },
  toObject: { virtuals: true },
})
export class IndentRaise {
  // =========================================================================
  // 1. Reference Data Structure Fields
  // =========================================================================

  /**
   * Unique business indent number, formatted as IND-YYYYMMDD-0001.
   * Concurrency-safe and atomic via MongoDB counter.
   */
  @Prop({ required: true, unique: true, index: true })
  indentNumber: string;

  /**
   * Group / Parent indent number when multiple items are combined in a single requisition.
   */
  @Prop({ default: '', index: true })
  groupIndentNumber?: string;

  /**
   * Authoritative item code from StoreNewItem.
   */
  @Prop({ default: '', index: true })
  itemCode: string;

  /**
   * Item description / specifications.
   */
  @Prop({ required: true, default: '' })
  itemDescription: string;

  /**
   * Manufacturer / Brand of the material.
   */
  @Prop({ default: '' })
  make: string;

  /**
   * Technical specifications of the material.
   */
  @Prop({ default: '' })
  techSpec: string;

  /**
   * Unit of measure (e.g. PCS, NOS, KG).
   */
  @Prop({ default: '' })
  unitOfMeasure: string;

  /**
   * Line number in the indent document.
   */
  @Prop({ default: 1 })
  lineNumber: number;

  /**
   * Indent creation timestamp.
   */
  @Prop({ default: Date.now })
  createdOn: Date;

  /**
   * Indent last changed timestamp.
   */
  @Prop({ default: Date.now })
  lastChangedOn: Date;

  /**
   * Quantity requested in this indent raise (>= 1).
   */
  @Prop({ required: true, min: 1 })
  indentQty: number;

  /**
   * Pre-requisite / prior unfulfilled demand quantity for this item.
   */
  @Prop({ default: 0 })
  preReqQty: number;

  /**
   * Purchase requisition pipeline quantity.
   */
  @Prop({ default: 0 })
  preqQty: number;

  /**
   * Available balance quantity in stock at the time of indent raise.
   */
  @Prop({ default: 0 })
  balanceQty: number;

  /**
   * Document category (default 'ITEM_MASTER').
   */
  @Prop({ default: 'ITEM_MASTER' })
  documentCategory: string;

  /**
   * Company code or name (default 'STORE').
   */
  @Prop({ default: 'STORE' })
  company: string;

  /**
   * Cost center code or name (default 'MAIN_STORE').
   */
  @Prop({ default: 'MAIN_STORE' })
  costCenter: string;

  /**
   * Document date.
   */
  @Prop({ default: Date.now })
  documentDate: Date;

  /**
   * Document type (default 'INDENT').
   */
  @Prop({ default: 'INDENT' })
  documentType: string;

  /**
   * Name or email of the authenticated requester.
   */
  @Prop({ default: '' })
  requestedBy: string;

  /**
   * Harmonized System of Nomenclature (HSN) code.
   */
  @Prop({ default: '' })
  hsnCode: string;

  // =========================================================================
  // 2. Application Workflow & Authorization Fields
  // =========================================================================

  /**
   * Reference to the StoreNewItem master record.
   */
  @Prop({
    type: mongoose.Schema.Types.ObjectId,
    ref: 'StoreNewItem',
    required: true,
    index: true,
  })
  itemId: Types.ObjectId;

  /**
   * Requester user identifier from req.user.
   */
  @Prop({ default: '' })
  requesterId: string;

  /**
   * Current lifecycle status: PENDING, APPROVED, REJECTED.
   */
  @Prop({
    default: 'PENDING',
    enum: ['PENDING', 'DEPT_APPROVED', 'APPROVED', 'REJECTED', 'CLOSED'],
    index: true,
  })
  status: string;

  /**
   * Department approval tracking
   */
  @Prop()
  deptApprovedAt?: Date;

  @Prop({ default: '' })
  deptApprovedBy?: string;

  @Prop({ default: '' })
  deptApprovedById?: string;

  /**
   * Store consolidation & approval tracking
   */
  @Prop()
  storeApprovedAt?: Date;

  @Prop({ default: '' })
  storeApprovedBy?: string;

  @Prop({ default: '' })
  storeApprovedById?: string;

  /**
   * Original quantity requested before Store auto-adjustment/capping
   */
  @Prop({ default: 0 })
  originalIndentQty?: number;

  /**
   * Review remarks provided upon approval or rejection.
   */
  @Prop({ default: '' })
  reviewRemarks?: string;

  /**
   * User name/email who reviewed (approved/rejected) the indent.
   */
  @Prop({ default: '' })
  reviewedBy?: string;

  /**
   * User ID who reviewed (approved/rejected) the indent.
   */
  @Prop({ default: '' })
  reviewedById?: string;

  /**
   * Review timestamp.
   */
  @Prop()
  reviewedAt?: Date;

  /**
   * Reason or justification for raising the indent.
   */
  @Prop({ default: '' })
  reason: string;

  /**
   * Snapshot of available stock at time of creation.
   */
  @Prop({ default: 0 })
  currentAvailableQty: number;

  /**
   * Snapshot of total stock at time of creation.
   */
  @Prop({ default: 0 })
  currentTotalQty: number;

  /**
   * Indicates whether physical inventory was credited directly upon approval or receive.
   */
  @Prop({ default: false, index: true })
  stockCredited: boolean;

  /**
   * Timestamp when physical stock was credited.
   */
  @Prop()
  stockCreditedAt?: Date;

  /**
   * Target rack ID where physical stock was credited.
   */
  @Prop({ default: '' })
  creditedRackId?: string;

  /**
   * Target rack code where physical stock was credited.
   */
  @Prop({ default: '' })
  creditedRackCode?: string;

  /**
   * Actual quantity credited to physical stock.
   */
  @Prop({ default: 0 })
  creditedQty?: number;

  /**
   * StoreReceive document ID if auto-received into rack.
   */
  @Prop({ default: '' })
  receiveDocId?: string;

  /**
   * Complete audit trail and lifecycle timeline of the indent.
   */
  @Prop({
    type: [
      {
        action: { type: String, required: true },
        title: { type: String, required: true },
        description: { type: String, default: '' },
        actorName: { type: String, default: '' },
        timestamp: { type: Date, default: Date.now },
      },
    ],
    default: [],
  })
  timeline?: Array<{
    action: string;
    title: string;
    description: string;
    actorName: string;
    timestamp: Date;
  }>;

  /**
   * Origin type of the indent:
   * - 'STORE_REFILL': Manual store inventory restock (default, destination: Available Stock)
   * - 'ISSUE_SHORTAGE': Shortage triggered during an Issue Request (destination: Auto-reserve for requester)
   * - 'AUTO_REFILL': System minimum-stock threshold auto-indent (destination: Available Stock)
   */
  @Prop({ default: 'STORE_REFILL', index: true })
  indentType?: string;

  /**
   * Linked Issue ID if triggered by a shortage during an issue request.
   */
  @Prop({ default: '' })
  sourceIssueId?: string;

  // =========================================================================
  // 3. Backward-Compatibility Aliases (for existing records and Flutter UI)
  // =========================================================================

  /**
   * Legacy alias for indentNumber.
   */
  @Prop({ index: true })
  requestNo?: string;

  /**
   * Legacy alias for itemDescription.
   */
  @Prop({ default: '' })
  itemName?: string;

  /**
   * Legacy alias for unitOfMeasure.
   */
  @Prop({ default: '' })
  unit?: string;

  /**
   * Legacy alias for indentQty.
   */
  @Prop({ min: 1 })
  requestedQty?: number;
}

export const IndentRaiseSchema = SchemaFactory.createForClass(IndentRaise);

// Ensure virtual 'id' returns the hex string _id
IndentRaiseSchema.virtual('id').get(function () {
  return this._id?.toHexString() || this._id?.toString();
});

// Backward compatibility alias for the schema class
export const StockRefillRequest = IndentRaise;
export const StockRefillRequestSchema = IndentRaiseSchema;
