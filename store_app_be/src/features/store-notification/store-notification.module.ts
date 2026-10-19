import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { StoreNotificationController } from './store-notification.controller';
import { StoreNotificationService } from './store-notification.service';
import {
  StoreNotification,
  StoreNotificationSchema,
} from './schemas/store-notification.schema';
import {
  StoreNewItem,
  StoreNewItemSchema,
} from '../new-store/store-items/store-item/entities/store-item.schema';
import {
  IndentRaise,
  IndentRaiseSchema,
} from '../stock-refill-request/schemas/stock-refill-request.schema';

@Module({
  imports: [
    MongooseModule.forFeature(
      [
        { name: StoreNotification.name, schema: StoreNotificationSchema },
        { name: StoreNewItem.name, schema: StoreNewItemSchema },
        { name: IndentRaise.name, schema: IndentRaiseSchema },
      ],
      'store',
    ),
  ],
  controllers: [StoreNotificationController],
  providers: [StoreNotificationService],
  exports: [StoreNotificationService],
})
export class StoreNotificationModule {}
