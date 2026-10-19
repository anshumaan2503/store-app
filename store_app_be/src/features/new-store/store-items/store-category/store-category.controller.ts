import { Body, Controller, Delete, Param, Post, Put, UseGuards } from '@nestjs/common';
import { StoreCategoryService } from './store-category.service';
import { CreateCategoryDto, UpdateCategoryDto } from './dto/store-category.dto';
import { StoreCategoryGateway } from './store-category.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/categories')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreCategoryController {
  constructor(
    private readonly s: StoreCategoryService,
    private readonly gateway: StoreCategoryGateway,
  ) {}

  @Post()
  @Permissions('storeitemadd', 'storeitemedit')
  async create(@Body() dto: CreateCategoryDto) {
    const data = await this.s.create(dto);
    this.gateway.broadcastAllRoomList().catch(() => {});
    return { status: true, msg: 'Created', data };
  }

  @Put(':id')
  @Permissions('storeitemedit')
  async update(
    @Param('id') id: string,
    @Body() dto: Omit<UpdateCategoryDto, 'id'>,
  ) {
    const data = await this.s.update({ ...dto, id });
    return { status: true, msg: 'Updated', data };
  }

  @Delete(':id')
  @Permissions('storeitemdelete')
  async delete(@Param('id') id: string) {
    await this.s.delete(id);
    return { status: true, msg: 'Deleted' };
  }
}
