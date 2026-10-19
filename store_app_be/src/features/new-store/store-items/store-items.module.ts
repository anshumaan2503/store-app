import { Module } from '@nestjs/common';
import { StoreItemNameModule } from './store-item-name/store-item-name.module';
import { StoreCategoryModule } from './store-category/store-category.module';
import { StoreNewItemModule } from './store-item/store-item.module';
import { StoreItemIssueModule } from './store-item-issue/store-item-issue.module';
import { StoreScrapModule } from './store-scrap/store-scrap.module';
import { StoreUnitNameModule } from './store-unit-name/store-unit-name.module';
import { StoreCartModule } from './store-cart/store-cart.module';
import { StoreGrnModule } from './store-grn/store-grn.module';

@Module({
  imports: [
    StoreItemNameModule,
    StoreCategoryModule,
    StoreNewItemModule,
    StoreItemIssueModule,
    StoreScrapModule,
    StoreUnitNameModule,
    StoreCartModule,
    StoreGrnModule,
  ],
})
export class StoreItemsModule {}
