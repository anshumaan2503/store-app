import { Type } from 'class-transformer';
import { IsInt, IsMongoId, IsOptional, IsString, Min, ValidateNested } from 'class-validator';

export class IssueOneLineDto {
  @IsString()
  issuedBy: string;

  @IsString()
  itemId: string; // StoreNewItem._id (same as IssueLine.itemId)

  @IsOptional()
  @IsString()
  rackId?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  qty: number;
}

export class IssueBulkLineDto {
  @IsString()
  itemId: string;

  @IsOptional()
  @IsString()
  rackId?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  qty: number;
}

export class IssueBulkDto {
  @IsString()
  issuedBy: string;

  @ValidateNested({ each: true })
  @Type(() => IssueBulkLineDto)
  lines: IssueBulkLineDto[];
}

export class ReturnLineDto {
  @IsMongoId()
  returnedBy: string;

  @IsMongoId()
  itemId: string;

  // good qty returned to stock
  @IsInt()
  @Min(0)
  goodQty: number;

  // scrap qty (removed from stock)
  @IsInt()
  @Min(0)
  scrapQty: number;
}

export class ReturnBulkDto {
  @IsMongoId()
  returnedBy: string;

  lines: { itemId: string; goodQty: number; scrapQty: number }[];
}
