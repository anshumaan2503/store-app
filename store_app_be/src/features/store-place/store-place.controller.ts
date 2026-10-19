import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Delete,
  Put,
  UseGuards,
} from '@nestjs/common';
import { StorePlaceService } from './store-place.service';
import { StorePlaceGateway } from './store-place.gateway';
import { CreateStorePlaceDto } from './dto/create-store-place.dto';
import { UpdateStorePlaceDto } from './dto/update-store-place.dto';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('/api/store')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StorePlaceController {
  constructor(
    private readonly storePlaceService: StorePlaceService,
    private readonly gateway: StorePlaceGateway,
  ) {}

  @Post('place')
  @Permissions('storeplaceadd')
  async create(@Body() createStorePlaceDto: CreateStorePlaceDto) {
    var data = await this.storePlaceService.create(createStorePlaceDto);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Get()
  @Permissions('storeplaceview')
  async findAll() {
    return await this.storePlaceService.findAll();
  }

  @Get(':id')
  @Permissions('storeplaceview')
  findOne(@Param('id') id: string) {
    return this.storePlaceService.findOne(id);
  }

  @Put('place/:id')
  @Permissions('storeplaceedit', 'storeplaceadd')
  async update(
    @Param('id') id: string,
    @Body() updateStorePlaceDto: UpdateStorePlaceDto,
  ) {
    var data = await this.storePlaceService.update(id, updateStorePlaceDto);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('placedelete/:id')
  @Permissions('storeplacedelete')
  async remove(@Param('id') id: string) {
    var data = await this.storePlaceService.remove(id);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }
}
