import { IsOptional, IsString } from 'class-validator';

export class CreateRoomDto {
  @IsOptional()
  @IsString()
  roomName?: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  isOneRack?: boolean;

  @IsOptional()
  @IsString()
  remark?: string;

  @IsOptional()
  isScrap?: boolean;

  @IsOptional()
  @IsString()
  createdBy?: string;
}
