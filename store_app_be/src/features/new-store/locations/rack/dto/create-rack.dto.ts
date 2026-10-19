import { IsOptional, IsString } from 'class-validator';

export class CreateRackDto {
  @IsString()
  roomId: string;

  @IsOptional()
  @IsString()
  rackName?: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsOptional()
  // @IsString()
  isScrap?: boolean;

  @IsOptional()
  @IsString()
  createdBy?: string;
}
