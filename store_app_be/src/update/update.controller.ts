import { Controller, Get, NotFoundException, Param } from '@nestjs/common';
import { UpdateService } from './update.service';

@Controller('update')
export class UpdateController {
  constructor(private readonly updateService: UpdateService) {}

  @Get('update/:type')
  async getLatestApk(@Param('type') type: string) {
    const latestApk = await this.updateService.cheakVersion(type);

    if (!latestApk) {
      throw new NotFoundException(`No update record found for type '${type}'`);
    }

    return {
      version: latestApk.version,
      apkUrl: latestApk.apkUrl,
    };
  }
}
// avinash.dewangan@rrispat.com
