import { Body, Controller, Delete, Param, Post, Put, UseGuards } from '@nestjs/common';
import { CreateItemNameDto, UpdateItemNameDto } from './dto/item-name.dto';
import { StoreItemNameService } from './store-item-name.service';
import { StoreItemNameGateway } from './store-item-name.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/item-names')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreItemNameController {
  constructor(
    private readonly s: StoreItemNameService,
    private readonly gateway: StoreItemNameGateway,
  ) {}

  @Post()
  @Permissions('storeitemadd', 'storeitemedit')
  async create(@Body() dto: CreateItemNameDto) {
    const data = await this.s.create(dto);
    this.gateway.broadcastAllList().catch(() => {});
    return { status: true, msg: 'Created', data };
  }

  @Put(':id')
  @Permissions('storeitemedit')
  async update(
    @Param('id') id: string,
    @Body() dto: Omit<UpdateItemNameDto, 'id'>,
  ) {
    const data = await this.s.update({ ...dto, id });
    this.gateway.broadcastAllList().catch(() => {});
    return { status: true, msg: 'Updated', data };
  }

  @Delete(':id')
  @Permissions('storeitemdelete')
  async delete(@Param('id') id: string) {
    await this.s.delete(id);
    return { status: true, msg: 'Deleted' };
  }
}
