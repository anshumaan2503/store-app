import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ReceivingService } from './item-receive.service';
import { ItemReceiveGateway } from './item-receive.gateway';
import {
  CreateItemReceiveDto,
  ReceiveStockDto,
} from './dto/create-item-receive.dto';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('/api/store/')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class ItemReceiveController {
  constructor(
    private readonly itemReceiveService: ReceivingService,
    private readonly gateway: ItemReceiveGateway,
  ) {}

  @Post('receive')
  @Permissions('storreceiveadd')
  async create(@Body() payload: CreateItemReceiveDto) {
    var data = await this.itemReceiveService.create(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Get()
  @Permissions('storreceiveview')
  findAll() {
    return this.itemReceiveService.findAll();
  }

  @Put('receive/:id')
  @Permissions('storreceiveedit', 'storreceiveadd')
  async update(@Body() payload: any) {
    var data = await this.itemReceiveService.updateDraft(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('receiveapprove/:id')
  @Permissions('storreceiveapprove')
  async approveReceive(@Param('id') id: string, @Body() payload: any) {
    var data = await this.itemReceiveService.approveReceive(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('receivereject')
  @Permissions('storreceivereject', 'storreceiveapprove')
  async receiveReject(@Param('id') id: string, @Body() payload: any) {
    var data = await this.itemReceiveService.rejectReceive(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('receivetoplace')
  @Permissions('storreceivetostock')
  async receivetoplace(@Body() payload: any) {
    var data = await this.itemReceiveService.receiveToPlaceOne(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('receiveclose')
  @Permissions('storreceiveclose', 'storreceiveapprove')
  async receiveclose(@Body() payload: any) {
    var data = await this.itemReceiveService.closeReceive(payload);
    this.gateway.broadcastAuthList().catch(() => {});
    return data;
  }

  @Put('places/:placeId/receive')
  @Permissions('storreceivetostock')
  async receiveToPlace(
    @Param('placeId') placeId: string,
    @Body() dto: ReceiveStockDto,
  ) {
    return await this.itemReceiveService.receiveToPlace(placeId, dto);
  }
}
