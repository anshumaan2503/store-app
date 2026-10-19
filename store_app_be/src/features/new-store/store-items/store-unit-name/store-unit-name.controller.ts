import { Body, Controller, Delete, Param, Post, Put, UseGuards } from '@nestjs/common';
import { StoreUnitNameService } from './store-unit-name.service';
import { CreateUnitNameDto, UpdateUnitNameDto } from './dto/unit-name.dto';
import { StoreUnitNameGateway } from './store-unit-name.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/unit-names')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreUnitNameController {
  constructor(
    private readonly s: StoreUnitNameService,
    private readonly gateway: StoreUnitNameGateway,
  ) {}

  @Post()
  @Permissions('storeitemadd', 'storeitemedit')
  async create(@Body() dto: CreateUnitNameDto) {
    const data = await this.s.create(dto);
    this.gateway.broadcastAllList().catch(() => {});
    return { status: true, msg: 'Created', data };
  }

  @Put(':id')
  @Permissions('storeitemedit')
  async update(
    @Param('id') id: string,
    @Body() dto: Omit<UpdateUnitNameDto, 'id'>,
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
