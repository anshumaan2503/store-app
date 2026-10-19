import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Socket } from 'dgram';
import { StoreScrapService } from './store-scrap.service';
import { ScrapPagedQueryDto } from './dto/create-store-scrap.dto';
import { StoreNewItemGateway } from '../store-item/store-item.gateway';

@WebSocketGateway({ cors: true })
export class StoreScrapGateway {
  @WebSocketServer() server: any;
  constructor(
    private readonly storeScrapService: StoreScrapService,
    private readonly storeNewItemGateway: StoreNewItemGateway,
  ) {}

  async broadcastAllScrapList() {
    const list = await this.storeScrapService.findAllScrapPaged({
      page: 1,
      limit: 12,
      search: '',
      sort: '-createdAt',
    });
    this.server.emit('store:findAllScrapPaged', list); // broadcast to all clients
    if (this.storeNewItemGateway) {
      await this.storeNewItemGateway.broadcastAllList().catch(() => {});
    }
  }

  @SubscribeMessage('store:findAllScrapPaged')
  async findAllScrapPaged(
    @ConnectedSocket() client: Socket,
    @MessageBody() q: ScrapPagedQueryDto,
  ) {
    const data = await this.storeScrapService.findAllScrapPaged(q || {});
    client.emit('store:findAllScrapPaged', data);
  }
}
