import {
  IsInt,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class ScrapPagedQueryDto {
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

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsString()
  sort?: string;
}

export class CreateStoreScrapDto {
  @IsMongoId()
  @IsNotEmpty()
  itemId: string;

  @IsMongoId()
  @IsNotEmpty()
  rackId: string;

  @IsOptional()
  @IsString()
  roomId?: string;

  @IsNumber()
  @Min(1)
  itemQuantity: number;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsMongoId()
  @IsNotEmpty()
  createdBy: string;

  @IsOptional()
  @IsString()
  requestId?: string;
}

export class UpdateStoreScrapDto {
  @IsMongoId()
  @IsNotEmpty()
  id: string;

  @IsMongoId()
  @IsNotEmpty()
  itemId: string;

  @IsMongoId()
  @IsNotEmpty()
  rackId: string;

  @IsOptional()
  @IsString()
  roomId?: string;

  @IsNumber()
  @Min(1)
  itemQuantity: number;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsMongoId()
  @IsNotEmpty()
  createdBy: string;
}
