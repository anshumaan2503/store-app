import { OnModuleInit } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { StoreCartService } from './store-cart.service';

@WebSocketGateway({ cors: { origin: '*' } })
export class StoreCartGateway implements OnModuleInit {
  @WebSocketServer() server: any;

  constructor(private readonly s: StoreCartService) {}

  onModuleInit() {
    // Periodically prune expired cart items and broadcast updated global totals to all clients
    setInterval(async () => {
      try {
        await this.broadcastGlobalTotals();
      } catch (err) {
        console.error('[StoreCartGateway] Auto-prune totals error:', err);
      }
    }, 20 * 1000);
  }

  async broadcastGlobalTotals() {
    if (!this.server) return;
    try {
      const totals = await this.s.getAllInCartQuantities();
      this.server.emit('store:cart:globalTotals', totals);
    } catch (_) {}
  }

  @SubscribeMessage('store:cart:getGlobalTotals')
  async handleGetGlobalTotals(@ConnectedSocket() client: Socket) {
    const totals = await this.s.getAllInCartQuantities();
    client.emit('store:cart:globalTotals', totals);
  }

  @SubscribeMessage('store:cart:getConfig')
  async handleGetConfig(@ConnectedSocket() client: Socket) {
    const config = await this.s.getConfig();
    client.emit('store:cart:configUpdated', config);
  }

  @SubscribeMessage('store:cart:itemBreakdown')
  async handleItemBreakdown(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: any,
  ) {
    const itemId = String(body?.itemId || '').trim();
    const data = await this.s.getItemCartBreakdown(itemId);
    client.emit('store:cart:itemBreakdown', { itemId, data });
  }

  @SubscribeMessage('store:cart:get')
  async handleGetCart(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { userId: string },
  ) {
    const userId = body?.userId;
    if (!userId) return;
    const items = await this.s.getCart(userId);
    client.emit('store:cart:updated', { userId, items });

    // Also send latest global in-cart totals
    const totals = await this.s.getAllInCartQuantities();
    client.emit('store:cart:globalTotals', totals);
  }

  @SubscribeMessage('store:cart:sync')
  async handleSyncCart(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { userId: string; items: any[] },
  ) {
    const userId = body?.userId;
    if (!userId) return;
    const items = await this.s.syncCart(userId, body.items || []);
    if (this.server) {
      // 1. Broadcast user's cart to that user's other devices
      this.server.emit('store:cart:updated', { userId, items });
      // 2. Broadcast global in-cart count to ALL accounts across the app!
      await this.broadcastGlobalTotals();
    }
  }

  @SubscribeMessage('store:cart:clear')
  async handleClearCart(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { userId: string },
  ) {
    const userId = body?.userId;
    if (!userId) return;
    await this.s.clearCart(userId);
    if (this.server) {
      this.server.emit('store:cart:updated', { userId, items: [] });
      await this.broadcastGlobalTotals();
    }
  }
}
