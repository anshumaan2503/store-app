import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { StoreGrnService } from './store-grn.service';
import { CreateGrnDto, RejectGrnDto } from './dto/create-grn.dto';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/grn')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreGrnController {
  constructor(private readonly grnService: StoreGrnService) {}

  @Post()
  @Permissions('storreceiveadd', 'storeitemview')
  async createGrn(@Body() dto: CreateGrnDto, @Request() req: any) {
    const user = req.user;
    return await this.grnService.createGrn(dto, user);
  }

  @Get()
  @Permissions('storreceiveview', 'storeitemview', 'storissueview')
  async listGrn(
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return await this.grnService.listGrn({
      status,
      search,
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });
  }

  @Get('active-item/:itemId')
  @Permissions('storreceiveview', 'storeitemview')
  async getActiveGrnForItem(@Param('itemId') itemId: string) {
    return await this.grnService.getActiveApprovedGrnForItem(itemId);
  }

  @Get(':id')
  @Permissions('storreceiveview', 'storeitemview')
  async getGrnById(@Param('id') id: string) {
    return await this.grnService.getGrnById(id);
  }

  @Put(':id/approve')
  @Permissions('storreceiveapprove')
  async approveGrn(@Param('id') id: string, @Request() req: any) {
    return await this.grnService.approveGrn(id, req.user);
  }

  @Put(':id/reject')
  @Permissions('storreceivereject', 'storreceiveapprove')
  async rejectGrn(
    @Param('id') id: string,
    @Body() dto: RejectGrnDto,
    @Request() req: any,
  ) {
    return await this.grnService.rejectGrn(id, dto?.reason || '', req.user);
  }

  @Post('upload-image')
  @Permissions('storreceiveadd', 'storeitemview')
  async uploadImage(@Body() body: { base64: string }) {
    const imageUrl = await this.grnService.uploadGrnImageBase64(body.base64);
    return { success: true, imageUrl };
  }
}
