import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { StoreNewItemService } from './store-item.service';
import {
  CreateItemDto,
  StoreItemReceiveDto,
  TransferItemDto,
  TransferRackDto,
  UpdateItemDto,
} from './dto/store-item.dto';
import { UploadBase64Dto } from 'src/features/store-item/schema/upload-image.dto';
import { StoreNewItemGateway } from './store-item.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/storeitems')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreNewItemController {
  constructor(
    private readonly s: StoreNewItemService,
    private readonly gateway: StoreNewItemGateway,
  ) {}

  @Post()
  @Permissions('storeitemadd')
  async create(@Body() dto: CreateItemDto) {
    const data = await this.s.create(dto);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return data;
  }

  @Put(':id')
  @Permissions('storeitemedit')
  async update(
    @Param('id') id: string,
    @Body() dto: Omit<UpdateItemDto, 'id'>,
  ) {
    const data = await this.s.update({ ...dto, id });
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { status: true, msg: 'Updated successfully', data };
  }

  @Put(':id/transfer-rack')
  @Permissions('storeitemtransfer', 'storeitemedit')
  async transferRack(
    @Param('id') itemId: string,
    @Body() dto: TransferRackDto,
  ) {
    await this.s.removeRackFromItem(itemId, dto.toRackId!, dto.createdBy);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { ok: true };
  }

  @Put('remove-rack')
  @Permissions('storeitemtransfer', 'storeitemedit')
  async removeRack(@Body() dto: any) {
    await this.s.removeRack(dto.toRackId, dto.createdBy);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { ok: true };
  }

  @Put(':id/transfer-item')
  @Permissions('storeitemtransfer', 'storeitemedit')
  async transferItem(
    @Param('id') itemId: string,
    @Body() dto: TransferItemDto,
  ) {
    await this.s.transferItemQty(
      itemId,
      dto.fromRackId!,
      dto.toRackId!,
      dto.qty!,
      dto.createdBy,
    );
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { ok: true };
  }

  @Post('receive')
  @Permissions('storreceiveadd')
  async receive(@Body() dto: StoreItemReceiveDto) {
    var data = await this.s.receiveItem(dto);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.gateway.broadcastAllReceiveList().catch(() => {});
    return data;
  }

  @Delete(':id')
  @Permissions('storeitemdelete')
  async delete(
    @Param('id') id: string,
    @Query('force') force: string,
    @Req() req: any,
  ) {
    const user = req.user;
    const isSuperAdmin = user?.isSuperAdmin === true;
    const perms: string[] = Array.isArray(user?.appWorks) ? user.appWorks : [];
    const isStoreAdmin = perms.includes('storeadmin');
    const canDelete =
      isSuperAdmin ||
      isStoreAdmin ||
      perms.includes('storeitemdelete');

    if (!canDelete) {
      throw new ForbiddenException(
        'Insufficient permissions. Only Super Admin, Store Admin, or users with "Item • Delete" permission can delete items',
      );
    }

    const forceDelete =
      isSuperAdmin ||
      isStoreAdmin ||
      perms.includes('storeitemdelete') ||
      force === 'true' ||
      force === '1';

    await this.s.delete(id, user?._id || user?.uid, forceDelete);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { status: true, msg: 'Deleted' };
  }

  @Post(':id/image/base64')
  @Permissions('storeitemedit')
  async uploadImage(@Param('id') id: string, @Body() dto: UploadBase64Dto) {
    const { imageUrl, entity } = await this.s.uploadImageBase64(
      'item',
      id,
      dto.base64,
      'store-items',
    );
    return { success: true, imageUrl, entity };
  }

  @Post(':id/receive/image/base64')
  @Permissions('storreceiveadd')
  async uploadImageRevice(
    @Param('id') id: string,
    @Body() dto: UploadBase64Dto,
  ) {
    const { imageUrl, entity } = await this.s.uploadImageBase64(
      'receive',
      id,
      dto.base64,
      'store-receive',
    );
    return { success: true, imageUrl, entity };
  }

  @Get('by-item-scrap/:id')
  @Permissions('scrapview', 'storeitemview', 'storissuereturn')
  getScrap(@Param('id') id: string) {
    return this.s.scrapByItemId(id);
  }

  @Get(':id/transactions')
  @Permissions('storeitemview', 'storissueview', 'storreceiveview')
  getItemTransactions(@Param('id') id: string) {
    return this.s.getItemTransactions(id);
  }

  @Get(':id/rate-history')
  @Permissions('storeitemrateview', 'storeadmin')
  async getItemRateHistory(@Param('id') id: string, @Req() req: any) {
    const user = req.user;
    const isSuperAdmin = user?.isSuperAdmin === true;
    const perms: string[] = Array.isArray(user?.appWorks) ? user.appWorks : [];
    const isStoreAdmin = perms.includes('storeadmin');
    const hasRateAccess = perms.includes('storeitemrateview');

    if (!isSuperAdmin && !isStoreAdmin && !hasRateAccess) {
      throw new ForbiddenException(
        'Insufficient permissions. Only Super Admin, Store Admin, and users with "Item • Rate View" permission can access rate history.',
      );
    }
    return this.s.getItemRateHistory(id);
  }
}

