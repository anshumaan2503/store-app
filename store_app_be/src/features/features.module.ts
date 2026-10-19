import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module.js';
import { UserModule } from './user/user.module.js';
import { StoreItemModule } from './store-item/store-item.module';
import { StorePlaceModule } from './store-place/store-place.module';
import { ItemReceiveModule } from './item-receive/item-receive.module';
import { ItemIssueModule } from './item-issue/item-issue.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { BagsModule } from './bags/bags.module';
import { SizesModule } from './sizes/sizes.module';
import { ItemsModule } from './items/items.module';
import { SortingJobModule } from './sorting-job/sorting-job.module';
import { GradeModule } from './grade/grade.module';
import { ActivityModule } from './activity/activity.module';
import { NewStoreModule } from './new-store/new-store.module';
import { StockRefillRequestModule } from './stock-refill-request/stock-refill-request.module';
import { StoreNotificationModule } from './store-notification/store-notification.module';

@Module({
  imports: [
    AuthModule,
    UserModule,
    StockRefillRequestModule,
    StoreNotificationModule,
    StoreItemModule,
    StorePlaceModule,
    ItemReceiveModule,
    ItemIssueModule,
    DashboardModule,
    BagsModule,
    SizesModule,
    ItemsModule,
    SortingJobModule,
    GradeModule,
    ActivityModule,
    NewStoreModule,
  ],
})
export class FeaturesModule {}
