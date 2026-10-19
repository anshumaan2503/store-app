import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
} from '@nestjs/common';
import { StoreScrapService } from './store-scrap.service';
import {
  CreateStoreScrapDto,
  UpdateStoreScrapDto,
} from './dto/create-store-scrap.dto';
import { StoreScrapGateway } from './store-scrap.gateway';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { PermissionsGuard } from 'src/features/guards/permissions.guard';
import { Permissions } from 'src/features/guards/permissions.decorator';

@Controller('api/store/itemscrap')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StoreScrapController {
  constructor(
    private readonly storeScrapService: StoreScrapService,
    private readonly gateway: StoreScrapGateway,
  ) {}

  @Post()
  @Permissions('scrapadd')
  async create(@Body() createStoreScrapDto: CreateStoreScrapDto) {
    await this.storeScrapService.create(createStoreScrapDto);
    this.gateway.broadcastAllScrapList().catch(() => {});
    return { status: true, msg: 'Scrap Added successfully' };
  }

  @Get()
  @Permissions('scrapview')
  findAll() {
    return this.storeScrapService.findAll();
  }

  @Get(':id')
  @Permissions('scrapview')
  findOne(@Param('id') id: string) {
    return this.storeScrapService.findOne(+id);
  }

  @Patch(':id')
  @Permissions('scrapadd')
  update(
    @Param('id') id: string,
    @Body() updateStoreScrapDto: UpdateStoreScrapDto,
  ) {
    return this.storeScrapService.update(+id, updateStoreScrapDto);
  }

  @Delete(':id')
  @Permissions('scrapdelete')
  remove(@Param('id') id: string) {
    return this.storeScrapService.remove(+id);
  }
}
