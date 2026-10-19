import {
  IsArray,
  IsBoolean,
  IsInt,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateItemDto {
  @IsOptional() @IsString() itemName?: string;
  @IsOptional() @IsString() rackId?: string;
  @IsOptional() @IsString() scrapRackId?: string;

  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsArray() subCategoryIds?: string[];

  @IsOptional() @IsString() unit?: string;
  @IsOptional() @Type(() => Number) @IsNumber() maxCapacity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() maxQuantity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() minStockQuantity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() minimumValue?: number;
  @IsOptional() @Type(() => Number) @IsNumber() defaultRefillQuantity?: number;
  @IsOptional() @IsString() description?: string;

  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() createdBy?: string;
}

export class UpdateItemDto {
  @IsString() id?: string;

  @IsOptional() @IsString() itemName?: string;
  @IsOptional() @IsString() rackId?: string;
  @IsOptional() @IsString() categoryId?: string | null;
  @IsOptional() @IsArray() categoryIds?: string[];
  @IsOptional() @IsString() unit?: string;
  @IsOptional() @Type(() => Number) @IsNumber() maxCapacity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() maxQuantity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() minStockQuantity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() minimumValue?: number;
  @IsOptional() @Type(() => Number) @IsNumber() defaultRefillQuantity?: number;
  @IsOptional() @IsBoolean() isIndentReady?: boolean;
  @IsOptional() @IsString() description?: string;

  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() createdBy?: string;
}

export class ItemPagedQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsString() sort?: string;

  @IsOptional() @IsString() rackId?: string;
  @IsOptional() @IsString() categoryId?: string;
}

export class ReceivePagedQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsString() sort?: string;
}

export class TransferRackDto {
  @IsMongoId()
  @IsNotEmpty()
  toRackId: string;

  @IsMongoId()
  @IsNotEmpty()
  createdBy: string;
}

export class TransferItemDto {
  @IsMongoId()
  @IsNotEmpty()
  fromRackId: string;

  @IsMongoId()
  @IsNotEmpty()
  toRackId: string;

  @IsInt()
  @Min(1)
  qty: number;

  @IsMongoId()
  @IsNotEmpty()
  createdBy: string;
}

export class StoreItemReceiveDto {
  @IsMongoId()
  @IsNotEmpty()
  itemId: string;

  @IsMongoId()
  @IsNotEmpty()
  rackId: string;

  @IsNumber()
  @Min(1)
  qty: number;

  @IsMongoId()
  @IsNotEmpty()
  receivedBy: string;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsOptional()
  @IsString()
  recNo?: string;

  @IsOptional()
  @IsString()
  requestId?: string;

  @IsOptional()
  @IsString()
  indentId?: string;

  @IsOptional()
  @IsBoolean()
  autoIssue?: boolean;

  @IsOptional()
  @IsNumber()
  unitPrice?: number;

  @IsOptional()
  @IsString()
  grnId?: string;

  @IsOptional()
  @IsString()
  grnNo?: string;
}
