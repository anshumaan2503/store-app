import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { OnModuleInit } from '@nestjs/common';
import { Socket } from 'socket.io';
import { IssueService } from './store-item-issue.service';
import { StoreNewItemGateway } from '../store-item/store-item.gateway';

@WebSocketGateway({ cors: { origin: '*' } })
export class IssueGateway implements OnModuleInit {
  @WebSocketServer() server: any;
  constructor(
    private readonly s: IssueService,
    private readonly storeNewItemGateway: StoreNewItemGateway,
  ) {}

  onModuleInit() {
    // Background auto-revert worker (runs every 30 seconds)
    setInterval(async () => {
      try {
        const revertedDrafts = await this.s.revertExpiredDrafts();
        const revertedIssues = await this.s.revertMonthEndUnclaimedIssues();
        if (revertedDrafts > 0 || revertedIssues > 0) {
          await this.broadcastAllIssueList().catch(() => {});
          if (this.storeNewItemGateway) {
            await this.storeNewItemGateway.broadcastAllList().catch(() => {});
          }
        }
      } catch (err) {
        console.error('[IssueGateway] Auto-revert error:', err);
      }
    }, 30 * 1000);
  }

  @SubscribeMessage('store:issue:sources')
  async sources(@ConnectedSocket() client: Socket, @MessageBody() body: any) {
    const itemId = String(body?.itemId || '').trim();
    const data = await this.s.getIssueSourcesForSelectedItem(itemId);
    client.emit('store:issue:sources', data);
  }

  @SubscribeMessage('store:issueByIdItem')
  async sourcesissueByIdItem(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: any,
  ) {
    // console.log(body);
    // const itemId = String(body?.issueId || '').trim();
    const data = await this.s.findIssuesByLineItemId(body);

    // console.log(data);

    client.emit('store:issueByIdItem', data);
  }

  @SubscribeMessage('store:issue:itemBreakdown')
  async handleItemBreakdown(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: any,
  ) {
    const itemId = String(body?.itemId || '').trim();
    const data = await this.s.getItemIssueBreakdown(itemId);
    client.emit('store:issue:itemBreakdown', { itemId, ...data });
  }

  @SubscribeMessage('store:issues:list')
  async issuesList(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: any,
  ) {
    const data = await this.s.findAllIssuesPaged(body);

    // respond on SAME event name (like your other ws)
    client.emit('store:issues:list', {
      ...data,
      createdBy: body?.createdBy ?? null,
      tab: body?.tab ?? 'all',
      isBroadcast: false,
    });
  }

  async broadcastAllIssueList() {
    var body = { sort: '-createdAt', search: '', page: 1, limit: 10 };
    const list = await this.s.findAllIssuesPaged(body);
    this.server.emit('store:issues:list', {
      ...list,
      createdBy: null,
      isBroadcast: true,
    }); // broadcast to all clients
  }

  @SubscribeMessage('store:issueByIdItemWithCategory')
  async sourcesIssueByIdItemWithCategory(
    @ConnectedSocket() client: Socket,
    // @MessageBody() body: any,
  ) {
    // const itemId = String(body?.issueId || '').trim();
    const data = await this.s.getMachineCategoriesWithIssuedItems();
    // console.log(data.categories);
    client.emit('store:issueByIdItemWithCategory', data.categories);
  }
}
