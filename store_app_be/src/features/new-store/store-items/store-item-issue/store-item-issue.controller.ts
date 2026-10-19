// issue.controller.ts
import { Body, Controller, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { IssueService } from './store-item-issue.service';
import {
  IssueOneLineDto,
  IssueBulkDto,
  ReturnBulkDto,
  ReturnLineDto,
} from './dto/create-store-item-issue.dto';
import { StoreNewItemGateway } from '../store-item/store-item.gateway';
import { IssueGateway } from './store-item-issue.gateway';
import { StoreCartService } from '../store-cart/store-cart.service';
import { StoreCartGateway } from '../store-cart/store-cart.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/issues')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class IssueController {
  constructor(
    private readonly s: IssueService,
    private readonly gateway: StoreNewItemGateway,
    private readonly issuegateway: IssueGateway,
    private readonly cartService: StoreCartService,
    private readonly cartGateway: StoreCartGateway,
  ) {}

  @Get('item/:itemId/breakdown')
  async getItemBreakdown(@Param('itemId') itemId: string) {
    const data = await this.s.getItemIssueBreakdown(itemId);
    return { status: true, data };
  }

  @Post('draft')
  @Permissions('storissueadd')
  async createDraft(@Body() dto: any) {
    const createdBy = String(dto?.createdBy || '').trim();
    let currentCartItems: any[] = [];
    if (createdBy) {
      currentCartItems = await this.cartService.getCart(createdBy).catch(() => []);
      await this.cartService.clearCart(createdBy).catch(() => {});
      if (this.cartGateway?.server) {
        this.cartGateway.server.emit('store:cart:updated', {
          userId: createdBy,
          items: [],
        });
      }
    }
    const issue = await this.s.createDraftBulk(dto);
    if (createdBy && currentCartItems.length > 0) {
      this.cartService.recordCartHistory(
        currentCartItems.map((it: any) => ({
          itemId: String(it.id || it._id || ''),
          itemName: it.itemName,
          itemCode: it.itemCode,
          unit: it.unit,
          userId: createdBy,
          quantity: it.quantity,
          addedAt: it.addedAt ? new Date(it.addedAt) : new Date(),
          revertedAt: new Date(),
          revertType: 'TRANSFERRED_TO_REQUESTED',
          issNo: issue?.issNo || '',
          issueId: String(issue?._id || ''),
          remark: `Transferred from Cart to Requisition #${issue?.issNo || ''}`,
        })),
      ).catch(() => {});
    }
    await this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Draft created', data: issue };
  }

  @Put(':id/approve')
  @Permissions('storissueapprove')
  async approve(@Param('id') id: string, @Body() dto: any) {
    await this.s.approveIssueBulk(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Approved' };
  }

  @Post(':id/approve')
  @Permissions('storissueapprove')
  async approvePost(@Param('id') id: string, @Body() dto: any) {
    return this.approve(id, dto);
  }

  @Put(':id/revert-approval')
  @Permissions('storissueapprove')
  async revertApproval(@Param('id') id: string, @Body() dto: any) {
    const data = await this.s.revertIssueApproval(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Approval reverted', data };
  }

  @Put(':id/reject')
  @Permissions('storissuereject', 'storissueapprove')
  async reject(@Param('id') id: string, @Body() dto: any) {
    const data = await this.s.rejectIssue(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Request rejected', data };
  }

  @Post(':id/lines/:itemId/approve')
  @Permissions('storissueapprove')
  async approveLine(
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: any,
  ) {
    const out = await this.s.approveIssueLine(id, itemId, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Line approved', data: out };
  }

  @Put(':id/issue-line')
  @Permissions('storissuefromstock')
  async issueLine(@Param('id') id: string, @Body() dto: any) {
    const data = await this.s.issueLine(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Issued', data };
  }

  @Put(':id/issue-bulk')
  @Permissions('storissuefromstock')
  async issueBulk(@Param('id') id: string, @Body() dto: IssueBulkDto) {
    const data = await this.s.issueBulk(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Issued', data };
  }

  @Post(':id/issue')
  @Permissions('storissuefromstock')
  async issue(@Param('id') id: string, @Body() dto: any) {
    await this.s.issueApproved(id, dto);
    this.cartGateway.broadcastGlobalTotals().catch(() => {});
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Issued' };
  }

  @Post(':id/return')
  @Permissions('storissuereturn')
  async returnItem(@Param('id') id: string, @Body() dto: any) {
    await this.s.returnAgainstAllocation(id, dto);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Returned' };
  }

  @Put(':id/return-line')
  @Permissions('storissuereturn')
  async returnLine(@Param('id') id: string, @Body() dto: any) {
    const data = await this.s.returnLine(id, dto);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Returned', data };
  }

  @Put(':id/return-bulk')
  @Permissions('storissuereturn')
  async returnBulk(@Param('id') id: string, @Body() dto: any) {
    const data = await this.s.returnBulk(id, dto);
    this.gateway.broadcastAllList().catch(() => {});
    this.gateway.broadcastAllScrapList().catch(() => {});
    this.issuegateway.broadcastAllIssueList().catch(() => {});
    return { status: true, msg: 'Returned bulk', data };
  }
}
