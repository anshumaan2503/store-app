import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class AddIndentDraftItemDto {
  @IsNotEmpty({ message: 'itemId is required' })
  @IsString({ message: 'itemId must be a string' })
  itemId: string;

  @IsNotEmpty({ message: 'quantity is required' })
  @IsNumber({}, { message: 'quantity must be a number' })
  @Min(1, { message: 'quantity must be at least 1' })
  quantity: number;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  itemName?: string;

  @IsOptional()
  @IsString()
  itemCode?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  indentType?: string;
}

export class AddIndentDraftBatchDto {
  @IsArray({ message: 'items must be an array' })
  @ValidateNested({ each: true })
  @Type(() => AddIndentDraftItemDto)
  items: AddIndentDraftItemDto[];
}

export class UpdateIndentDraftItemDto {
  @IsNotEmpty({ message: 'quantity is required' })
  @IsNumber({}, { message: 'quantity must be a number' })
  @Min(1, { message: 'quantity must be at least 1' })
  quantity: number;

  @IsOptional()
  @IsString()
  reason?: string;
}

export class SubmitCombinedIndentDto {
  /**
   * Specific item IDs to include in the combined indent.
   * If omitted or empty, all draft items belonging to the requester are submitted.
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  itemIds?: string[];

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  company?: string;

  @IsOptional()
  @IsString()
  costCenter?: string;
}
