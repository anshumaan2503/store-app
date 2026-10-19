import { IsArray, IsNotEmpty, IsNumber, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateGrnItemDto {
  @IsOptional()
  @IsString()
  indentId?: string;

  @IsOptional()
  @IsString()
  indentNumber?: string;

  @IsNotEmpty()
  @IsString()
  itemId: string;

  @IsNotEmpty()
  @IsString()
  itemName: string;

  @IsOptional()
  @IsString()
  itemCode?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsNumber()
  orderedQty: number;

  @IsNumber()
  receivedQty: number;

  @IsNumber()
  unitPrice: number;
}

export class CreateGrnDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateGrnItemDto)
  items: CreateGrnItemDto[];

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  remarks?: string;

  @IsOptional()
  submittedBy?: {
    uid: string;
    name: string;
    email?: string;
  };
}

export class RejectGrnDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
