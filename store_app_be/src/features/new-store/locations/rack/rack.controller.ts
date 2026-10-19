import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CreateRackDto } from './dto/create-rack.dto';
import { UpdateRackDto } from './dto/update-rack.dto';
import { RacksService } from './rack.service';
import { RackGateway } from './rack.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/racks')
export class RacksController {
  constructor(
    private readonly service: RacksService,
    private readonly gateway: RackGateway,
  ) {}

  @Post()
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @Permissions('storeplaceadd')
  async create(@Body() dto: CreateRackDto) {
    var data = await this.service.create(dto);
    this.gateway.broadcastAllRackList(data.data.roomId).catch(() => {});
    this.gateway.broadcastAllRackScrapList(data.data.roomId).catch(() => {});
    return data;
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @Permissions('storeplaceedit', 'storeplaceadd')
  async update(@Param('id') id: string, @Body() dto: UpdateRackDto) {
    var data = await this.service.update(id, dto);
    this.gateway.broadcastAllRackList(data.data.roomId).catch(() => {});
    this.gateway.broadcastAllRackScrapList(data.data.roomId).catch(() => {});
    return;
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @Permissions('storeplacedelete')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }

  @Get('by-item/:id')
  getByItem(@Param('id') id: string) {
    return this.service.findRackByItem(id);
  }

  @Get('by-room/:id')
  getByRoom(@Param('id') id: string, @Query('itemId') itemId: string) {
    return this.service.findRackByRoom(id, itemId);
  }
}

