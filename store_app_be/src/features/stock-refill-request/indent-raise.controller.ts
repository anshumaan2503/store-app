import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IndentRaiseService } from './stock-refill-request.service';
import {
  CreateIndentRaiseDto,
  ReviewIndentRaiseDto,
  UpdateIndentQtyDto,
  ConsolidatedStoreApproveDto,
  ApproveIndentItemDto,
  ApproveWholeIndentDto,
} from './dto/create-indent-raise.dto';
import {
  AddIndentDraftBatchDto,
  AddIndentDraftItemDto,
  SubmitCombinedIndentDto,
  UpdateIndentDraftItemDto,
} from './dto/indent-draft.dto';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/indents')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class IndentRaiseController {
  constructor(private readonly service: IndentRaiseService) {}

  // =========================================================================
  // Requester Indent Drafts (Unsubmitted Holding Area with Real-Time Stock)
  // =========================================================================

  @Get('drafts')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft', 'storeindentview')
  async getDrafts(@Req() req: any) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const data = await this.service.getDrafts(userId);
    return {
      status: true,
      data,
    };
  }

  @Post('drafts')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft', 'storeindentraise')
  async addDrafts(
    @Body() body: AddIndentDraftItemDto | AddIndentDraftBatchDto,
    @Req() req: any,
  ) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const items: AddIndentDraftItemDto[] = Array.isArray((body as any)?.items)
      ? (body as AddIndentDraftBatchDto).items
      : [body as AddIndentDraftItemDto];
    const data = await this.service.addDraftItems(userId, items);
    return {
      status: true,
      msg: 'Items added to Indent Review',
      data,
    };
  }

  @Put('drafts/:itemId')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft')
  async updateDraftItem(
    @Param('itemId') itemId: string,
    @Body() dto: UpdateIndentDraftItemDto,
    @Req() req: any,
  ) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const data = await this.service.updateDraftItemQty(userId, itemId, dto);
    return {
      status: true,
      msg: 'Draft item updated',
      data,
    };
  }

  @Delete('drafts/:itemId')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft')
  async removeDraftItem(@Param('itemId') itemId: string, @Req() req: any) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const data = await this.service.removeDraftItem(userId, itemId);
    return {
      status: true,
      msg: 'Draft item removed',
      data,
    };
  }

  @Delete('drafts')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft')
  async clearDrafts(@Req() req: any) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const data = await this.service.clearDrafts(userId);
    return {
      status: true,
      msg: 'All draft items cleared',
      data,
    };
  }

  @Post('submit-combined')
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentdraft', 'storeindentraise')
  async submitCombined(
    @Body() dto: SubmitCombinedIndentDto,
    @Req() req: any,
  ) {
    const userId = (req.user?._id || req.user?.uid || '').toString();
    const data = await this.service.submitCombined(userId, dto, req.user);
    return {
      status: true,
      msg: 'Combined indent submitted successfully and pending approval',
      data,
    };
  }

  // =========================================================================
  // Standard Indent Endpoints
  // =========================================================================

  @Post()
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentraise', 'storeindentdraft')
  async create(@Body() dto: CreateIndentRaiseDto, @Req() req: any) {
    const data = await this.service.create(dto, req.user);
    return {
      status: true,
      msg: 'Indent raised successfully',
      data,
    };
  }

  @Get()
  @Permissions(
    'storrefillview',
    'storreceiveview',
    'storissueview',
    'storissueapprove',
    'storissueadd',
    'storeadmin',
    'storeindentview',
    'storeindenthistory',
    'storeindentconsolidation',
  )
  async findAll(
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('itemId') itemId?: string,
    @Query('uncredited') uncredited?: string,
  ) {
    const isUncredited = uncredited === 'true' || uncredited === '1';
    const data = await this.service.findAll(
      status,
      search,
      itemId,
      isUncredited,
    );
    return {
      status: true,
      data,
    };
  }

  @Post('trigger-eod-scheduler')
  @Permissions('storeadmin', 'storrefillapprove', 'storreceiveapprove', 'storissueapprove')
  async triggerEodScheduler() {
    const data = await this.service.runEndOfDayAutoIndentScheduler();
    return {
      status: true,
      msg: data.msg,
      data,
    };
  }

  @Get('indent-ready-items')
  @Permissions(
    'storeitemview',
    'storrefillview',
    'storreceiveview',
    'storissueview',
    'storissueadd',
    'storeadmin',
    'storeindentview',
    'storeindentraise',
  )
  async getIndentReadyItems() {
    const data = await this.service.getIndentReadyItems();
    return {
      status: true,
      data,
    };
  }

  @Get('pending-store-consolidation')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storreceiveadd',
    'storeadmin',
    'storeindentconsolidation',
    'storeindentapprove',
    'storeindentview',
  )
  async getPendingStoreConsolidation(
    @Query('search') search?: string,
    @Query('groupBy') groupBy?: string,
  ) {
    const data = await this.service.getPendingStoreConsolidation(search, groupBy);
    return {
      status: true,
      data,
    };
  }

  @Post('approve-item/:id')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storeadmin',
    'storeindentapprove',
  )
  async approveIndentItem(
    @Param('id') id: string,
    @Body() dto: ApproveIndentItemDto,
    @Req() req: any,
  ) {
    const data = await this.service.approveIndentItem(id, dto, req.user);
    return {
      status: true,
      msg: data.message,
      data,
    };
  }

  @Post('approve-whole-indent/:indentNumber')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storeadmin',
    'storeindentapprove',
  )
  async approveWholeIndent(
    @Param('indentNumber') indentNumber: string,
    @Body() dto: ApproveWholeIndentDto,
    @Req() req: any,
  ) {
    const data = await this.service.approveWholeIndent(indentNumber, dto, req.user);
    return {
      status: true,
      msg: data.message,
      data,
    };
  }

  @Post('reject-whole-indent/:indentNumber')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storreceivereject',
    'storeadmin',
    'storeindentreject',
    'storeindentapprove',
  )
  async rejectWholeIndent(
    @Param('indentNumber') indentNumber: string,
    @Body() dto: { remarks?: string },
    @Req() req: any,
  ) {
    const data = await this.service.rejectWholeIndent(indentNumber, dto, req.user);
    return {
      status: true,
      msg: data.message,
      data,
    };
  }

  @Post('consolidated-store-approve')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storeadmin',
    'storeindentapprove',
  )
  async consolidatedStoreApprove(
    @Body() dto: ConsolidatedStoreApproveDto,
    @Req() req: any,
  ) {
    const data = await this.service.consolidatedStoreApprove(dto, req.user);
    return {
      status: true,
      msg: data.message,
      data,
    };
  }

  @Post('trigger-auto-close')
  @Permissions('storeadmin')
  async triggerAutoClose() {
    const data = await this.service.autoCloseExpiredIndents();
    return {
      status: true,
      msg: `Auto-close sweep completed: ${data.closedCount} indent(s) closed (older than ${data.days} days).`,
      data,
    };
  }

  @Get(':id')
  @Permissions(
    'storrefillview',
    'storreceiveview',
    'storissueview',
    'storissueapprove',
    'storissueadd',
    'storeadmin',
    'storeindentview',
    'storeindenthistory',
  )
  async findOne(@Param('id') id: string) {
    const data = await this.service.findOne(id);
    return {
      status: true,
      data,
    };
  }

  @Put(':id/approve')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storissueapprove',
    'storeadmin',
    'storeindentapprove',
  )
  async approve(
    @Param('id') id: string,
    @Body() dto: ReviewIndentRaiseDto,
    @Req() req: any,
  ) {
    const data = await this.service.approve(id, dto, req.user);
    return {
      status: true,
      msg: dto?.directStockIn
        ? 'Indent approved and stock credited successfully'
        : 'Indent approved successfully',
      data,
    };
  }

  @Put(':id/credit-stock')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storissueapprove',
    'storeadmin',
    'storeindentapprove',
  )
  async creditStock(
    @Param('id') id: string,
    @Body() dto: ReviewIndentRaiseDto,
    @Req() req: any,
  ) {
    const data = await this.service.creditStock(id, dto, req.user);
    return {
      status: true,
      msg: 'Stock credited to rack and available inventory updated successfully',
      data,
    };
  }

  @Put(':id/reject')
  @Permissions(
    'storrefillapprove',
    'storreceiveapprove',
    'storreceivereject',
    'storissueapprove',
    'storissuereject',
    'storeadmin',
    'storeindentreject',
    'storeindentapprove',
  )
  async reject(
    @Param('id') id: string,
    @Body() dto: ReviewIndentRaiseDto,
    @Req() req: any,
  ) {
    const data = await this.service.reject(id, dto, req.user);
    return {
      status: true,
      msg: 'Indent rejected successfully',
      data,
    };
  }

  @Put(':id/update-qty')
  @Permissions(
    'storeitemview',
    'storrefilladd',
    'storrefillapprove',
    'storreceiveapprove',
    'storissueapprove',
    'storissueedit',
    'storissueadd',
    'storeadmin',
    'storeindentdraft',
    'storeindentapprove',
  )
  async updateQuantity(
    @Param('id') id: string,
    @Body() dto: UpdateIndentQtyDto,
    @Req() req: any,
  ) {
    const data = await this.service.updateQuantity(id, dto, req.user);
    return {
      status: true,
      msg: 'Indent quantity updated successfully',
      data,
    };
  }

  @Delete(':id')
  @Permissions(
    'storeadmin',
    'storrefillapprove',
    'storreceiveapprove',
    'storissueapprove',
    'storrefilladd',
    'storissueadd',
    'storissueedit',
    'storeindentdraft',
  )
  async delete(@Param('id') id: string, @Req() req: any) {
    const data = await this.service.delete(id, req.user);
    return {
      status: true,
      msg: data.msg || 'Indent deleted successfully',
      data,
    };
  }
}
