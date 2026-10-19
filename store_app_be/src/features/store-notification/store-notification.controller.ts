import {
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from 'src/features/guards/jwt-auth.guard';
import { StoreNotificationService } from './store-notification.service';

@Controller('api/store/notifications')
@UseGuards(JwtAuthGuard)
export class StoreNotificationController {
  constructor(private readonly service: StoreNotificationService) {}

  @Get()
  async getNotifications(@Req() req: any) {
    const userId = (req.user?._id || req.user?.id || req.user?.uid || '').toString();
    const data = await this.service.getNotifications(userId);
    return {
      status: true,
      data,
    };
  }

  @Get('unread-count')
  async getUnreadCount(@Req() req: any) {
    const userId = (req.user?._id || req.user?.id || req.user?.uid || '').toString();
    const data = await this.service.getUnreadCount(userId);
    return {
      status: true,
      data,
    };
  }

  @Patch('read-all')
  async markAllAsRead(@Req() req: any) {
    const userId = (req.user?._id || req.user?.id || req.user?.uid || '').toString();
    const data = await this.service.markAllAsRead(userId);
    return {
      status: true,
      msg: 'All notifications marked as read',
      data,
    };
  }

  @Patch(':id/read')
  async markAsRead(@Param('id') id: string, @Req() req: any) {
    const userId = (req.user?._id || req.user?.id || req.user?.uid || '').toString();
    const data = await this.service.markAsRead(id, userId);
    return {
      status: true,
      msg: 'Notification marked as read',
      data,
    };
  }

  @Delete(':id')
  async removeNotification(@Param('id') id: string, @Req() req: any) {
    const userId = (req.user?._id || req.user?.id || req.user?.uid || '').toString();
    const data = await this.service.removeNotification(id, userId);
    return {
      status: true,
      msg: 'Notification removed',
      data,
    };
  }
}
