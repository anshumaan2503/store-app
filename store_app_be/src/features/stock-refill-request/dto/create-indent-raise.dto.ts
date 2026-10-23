import {
  IsBoolean,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateIndentRaiseDto {
  @IsNotEmpty({ message: 'itemId is required and cannot be empty' })
  @IsString({ message: 'itemId must be a valid string' })
  itemId: string;

  /**
   * Primary indent quantity requested (>= 1).
   * Either indentQty or requestedQty must be provided and >= 1.
   */
  @IsOptional()
  @IsNumber({}, { message: 'indentQty must be a number' })
  @Min(1, { message: 'indentQty must be at least 1' })
  indentQty?: number;

  /**
   * Legacy alias for indentQty (supported for backward compatibility).
   */
  @IsOptional()
  @IsNumber({}, { message: 'requestedQty must be a number' })
  @Min(1, { message: 'requestedQty must be at least 1' })
  requestedQty?: number;

  /**
   * Reason or justification for raising the indent.
   */
  @IsOptional()
  @IsString()
  reason?: string;

  /**
   * Material description (defaults to item master description / itemName if omitted).
   */
  @IsOptional()
  @IsString()
  itemDescription?: string;

  /**
   * Brand or manufacturer of the material.
   */
  @IsOptional()
  @IsString()
  make?: string;

  /**
   * Technical specifications of the material.
   */
  @IsOptional()
  @IsString()
  techSpec?: string;

  /**
   * Unit of measure (e.g. PCS, NOS, KG). Defaults to item master unit if omitted.
   */
  @IsOptional()
  @IsString()
  unitOfMeasure?: string;

  /**
   * Line number in the indent requisition document (default 1).
   */
  @IsOptional()
  @IsNumber({}, { message: 'lineNumber must be a number' })
  @Min(1, { message: 'lineNumber must be >= 1' })
  lineNumber?: number;

  /**
   * Pre-requisite / prior unfulfilled demand quantity for this item (default 0).
   */
  @IsOptional()
  @IsNumber({}, { message: 'preReqQty must be a number' })
  @Min(0, { message: 'preReqQty must be >= 0' })
  preReqQty?: number;

  /**
   * Purchase requisition pipeline quantity (default 0).
   */
  @IsOptional()
  @IsNumber({}, { message: 'preqQty must be a number' })
  @Min(0, { message: 'preqQty must be >= 0' })
  preqQty?: number;

  /**
   * Available balance quantity in stock at the time of indent raise.
   * NOTE: Ignored for persistence. The backend authoritatively calculates and snapshots
   * balanceQty from StoreNewItem.stockAvailableQuantity.
   */
  @IsOptional()
  @IsNumber({}, { message: 'balanceQty must be a number' })
  @Min(0, { message: 'balanceQty must be >= 0' })
  balanceQty?: number;

  /**
   * Document category (default 'ITEM_MASTER').
   */
  @IsOptional()
  @IsString()
  documentCategory?: string;

  /**
   * Company identifier (default 'STORE').
   */
  @IsOptional()
  @IsString()
  company?: string;

  /**
   * Cost center identifier (default 'MAIN_STORE').
   */
  @IsOptional()
  @IsString()
  costCenter?: string;

  /**
   * Date of document generation (ISO-8601 string, default current timestamp).
   */
  @IsOptional()
  @IsDateString({}, { message: 'documentDate must be a valid ISO date string' })
  documentDate?: string;

  /**
   * Document type code or name (default 'INDENT').
   */
  @IsOptional()
  @IsString()
  documentType?: string;

  /**
   * Harmonized System of Nomenclature (HSN) code for taxation/procurement.
   */
  @IsOptional()
  @IsString()
  hsnCode?: string;

  /**
   * Origin type of the indent:
   * - 'STORE_REFILL': Manual store inventory restock (default, destination: Available Stock)
   * - 'ISSUE_SHORTAGE': Shortage triggered during an Issue Request (destination: Auto-reserve for requester)
   * - 'AUTO_REFILL': System minimum-stock threshold auto-indent (destination: Available Stock)
   */
  @IsOptional()
  @IsString()
  indentType?: string;

  @IsOptional()
  @IsString()
  sourceIssueId?: string;
}

export class ReviewIndentRaiseDto {
  @IsOptional()
  @IsString()
  reviewRemarks?: string;

  /**
   * If true, immediately credits the physical inventory into the designated rack.
   */
  @IsOptional()
  @IsBoolean()
  directStockIn?: boolean;

  /**
   * Target rack ID to credit stock into.
   */
  @IsOptional()
  @IsString()
  rackId?: string;

  /**
   * Override quantity to credit (defaults to indentQty).
   */
  @IsOptional()
  @IsNumber()
  creditQty?: number;

  @IsOptional()
  @IsBoolean()
  overrideMaxCapacity?: boolean;
}

export class UpdateIndentQtyDto {
  @IsOptional()
  @IsNumber({}, { message: 'indentQty must be a number' })
  @Min(1, { message: 'indentQty must be at least 1' })
  indentQty?: number;

  @IsOptional()
  @IsNumber({}, { message: 'requestedQty must be a number' })
  @Min(1, { message: 'requestedQty must be at least 1' })
  requestedQty?: number;

  @IsOptional()
  @IsString()
  reason?: string;
}

export class ConsolidatedStoreApproveItemDto {
  @IsNotEmpty()
  @IsString()
  indentId: string;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  approvedQty: number;

  @IsOptional()
  @IsString()
  remarks?: string;
}

export class ConsolidatedStoreApproveDto {
  @IsNotEmpty()
  items: ConsolidatedStoreApproveItemDto[];

  @IsOptional()
  @IsString()
  overallRemarks?: string;

  @IsOptional()
  @IsBoolean()
  overrideMaxCapacity?: boolean;
}

export class ApproveIndentItemDto {
  @IsOptional()
  @IsNumber()
  @Min(1)
  approvedQty?: number;

  @IsOptional()
  @IsString()
  remarks?: string;

  @IsOptional()
  @IsBoolean()
  overrideMaxCapacity?: boolean;
}

export class ApproveWholeIndentDto {
  @IsOptional()
  @IsString()
  remarks?: string;

  @IsOptional()
  @IsBoolean()
  overrideMaxCapacity?: boolean;
}


