import {
  IsArray,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
  ArrayMinSize,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateItemReceiveLineDto {
  @IsMongoId()
  @IsNotEmpty()
  itemid: string;

  @IsNumber()
  @Min(1)
  receiveqty: number;

  @IsOptional()
  @IsString()
  itemname?: string;

  @IsOptional()
  @IsString()
  unit?: string;
}

export class CreateItemReceiveDto {
  @IsOptional()
  @IsString()
  recNo?: string;

  @IsOptional()
  @IsString()
  source?: string;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateItemReceiveLineDto)
  lines: CreateItemReceiveLineDto[];

  @IsMongoId()
  @IsNotEmpty()
  userId: string;
}

export class ReceiveStockDto {
  @IsMongoId()
  itemId: string;

  @IsNumber()
  @Min(1)
  qty: number;

  @IsOptional()
  @IsString()
  itemName?: string;

  @IsOptional()
  @IsString()
  placeName?: string;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsOptional()
  @IsString()
  createdBy?: string;
}
