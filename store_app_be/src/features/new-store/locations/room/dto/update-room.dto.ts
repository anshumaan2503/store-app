import { IsOptional, IsString } from 'class-validator';

export class UpdateRoomDto {
  @IsOptional()
  @IsString()
  roomName?: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  remark?: string;
}
