import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { StoreCartService } from './store-cart.service';
import { StoreCartGateway } from './store-cart.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/cart')
export class StoreCartController {
  constructor(
    private readonly s: StoreCartService,
    private readonly gateway: StoreCartGateway,
  ) {}

  @Get('global/totals')
  async getGlobalTotals() {
    const data = await this.s.getAllInCartQuantities();
    return { status: true, data };
  }

  @Get('item/:itemId/breakdown')
  async getItemBreakdown(@Param('itemId') itemId: string) {
    const data = await this.s.getItemCartBreakdown(itemId);
    return { status: true, data };
  }

  @Get('config')
  async getConfig() {
    const data = await this.s.getConfig();
    return { status: true, data };
  }

  @Post('config')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @Permissions('storeadmin')
  async updateConfig(
    @Body()
    body: {
      cartTimeoutMinutes?: number;
      cartTimeoutEnabled?: boolean;
      requestTimeoutDays?: number;
      requestTimeoutEnabled?: boolean;
      monthEndRevertEnabled?: boolean;
      indentApprovalRequired?: boolean;
      grnWorkflowEnabled?: boolean;
      updatedBy?: string;
    },
  ) {
    const data = await this.s.updateConfig(body);
    if (this.gateway?.server) {
      this.gateway.server.emit('store:cart:configUpdated', data);
      await this.gateway.broadcastGlobalTotals();
    }
    return { status: true, data };
  }

  @Get(':userId')
  async getCart(@Param('userId') userId: string) {
    const items = await this.s.getCart(userId);
    return { status: true, data: items };
  }

  @Post('sync')
  async syncCart(@Body() body: { userId: string; items: any[] }) {
    const items = await this.s.syncCart(body.userId, body.items);
    if (this.gateway?.server) {
      this.gateway.server.emit('store:cart:updated', {
        userId: body.userId,
        items,
      });
      await this.gateway.broadcastGlobalTotals();
    }
    return { status: true, data: items };
  }

  @Post('clear')
  async clearCart(@Body() body: { userId: string }) {
    await this.s.clearCart(body.userId);
    if (this.gateway?.server) {
      this.gateway.server.emit('store:cart:updated', {
        userId: body.userId,
        items: [],
      });
      await this.gateway.broadcastGlobalTotals();
    }
    return { status: true, data: [] };
  }
}
