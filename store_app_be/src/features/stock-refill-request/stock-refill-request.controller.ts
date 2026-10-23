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
  CreateStockRefillRequestDto,
  ReviewStockRefillRequestDto,
  UpdateStockRefillRequestDto,
} from './dto/create-stock-refill-request.dto';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

/**
 * Backward compatibility controller for existing Flutter client and legacy routes.
 * Routes under /api/store/refill-requests delegate directly to IndentRaiseService.
 */
@Controller('api/store/refill-requests')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StockRefillRequestController {
  constructor(private readonly service: IndentRaiseService) {}

  @Post()
  @Permissions('storeitemview', 'storrefilladd', 'storissueadd', 'storeindentraise', 'storeindentdraft')
  async create(@Body() dto: CreateStockRefillRequestDto, @Req() req: any) {
    const data = await this.service.create(dto, req.user);
    return {
      status: true,
      msg: 'Stock refill request submitted successfully',
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
    @Body() dto: ReviewStockRefillRequestDto,
    @Req() req: any,
  ) {
    const data = await this.service.approve(id, dto, req.user);
    return {
      status: true,
      msg: dto?.directStockIn
        ? 'Stock refill request approved and stock credited successfully'
        : 'Stock refill request approved successfully',
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
    @Body() dto: ReviewStockRefillRequestDto,
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
    @Body() dto: ReviewStockRefillRequestDto,
    @Req() req: any,
  ) {
    const data = await this.service.reject(id, dto, req.user);
    return {
      status: true,
      msg: 'Stock refill request rejected successfully',
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
    @Body() dto: UpdateStockRefillRequestDto,
    @Req() req: any,
  ) {
    const data = await this.service.updateQuantity(id, dto, req.user);
    return {
      status: true,
      msg: 'Stock refill request quantity updated successfully',
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
      msg: data.msg || 'Stock refill request deleted successfully',
      data,
    };
  }
}
