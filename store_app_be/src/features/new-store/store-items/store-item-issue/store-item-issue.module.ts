import { forwardRef, Module } from '@nestjs/common';
import { IssueService } from './store-item-issue.service';
import { IssueController } from './store-item-issue.controller';
import { IssueGateway } from './store-item-issue.gateway';
import { MongooseModule } from '@nestjs/mongoose';
import { Rack, RackSchema } from '../../locations/rack/entities/rack.schema';
import {
  StoreCategory,
  StoreCategorySchema,
} from '../store-category/entities/store-category.schema';
import {
  StoreItemName,
  StoreItemNameSchema,
} from '../store-item-name/entities/store-item-name.schema';
import {
  StoreNewItem,
  StoreNewItemSchema,
} from '../store-item/entities/store-item.schema';
import { ItemIssue, ItemIssueSchema } from './entities/store-item-issue.schema';
import {
  StockTrack,
  StockTrackSchema,
} from '../store-item/entities/stock-track.schema';
import {
  ItemRackQty,
  ItemRackQtySchema,
} from '../../locations/rack/entities/item-rack-qty.schema';
import { StoreNewItemModule } from '../store-item/store-item.module';
import { StoreCartModule } from '../store-cart/store-cart.module';
import { UserModule } from 'src/features/user/user.module';
import { Bag, BagSchema } from 'src/features/bags/entities/bag.schema';
import { Machine, MachineSchema } from 'src/features/sorting-job/entities/machine.schema';
import { StockRefillRequestModule } from 'src/features/stock-refill-request/stock-refill-request.module';

@Module({
  imports: [
    MongooseModule.forFeature(
      [
        { name: StoreNewItem.name, schema: StoreNewItemSchema },
        { name: StoreCategory.name, schema: StoreCategorySchema },
        { name: StoreItemName.name, schema: StoreItemNameSchema },
        { name: Rack.name, schema: RackSchema },
        { name: ItemIssue.name, schema: ItemIssueSchema },
        { name: StockTrack.name, schema: StockTrackSchema },
        { name: ItemRackQty.name, schema: ItemRackQtySchema },
        { name: Bag.name, schema: BagSchema },
        { name: Machine.name, schema: MachineSchema },
      ],
      'store',
    ),
    UserModule,
    forwardRef(() => StoreNewItemModule),
    forwardRef(() => StoreCartModule),
    forwardRef(() => StockRefillRequestModule),
  ],
  controllers: [IssueController],
  providers: [IssueService, IssueGateway],
  exports: [IssueService],
})
export class StoreItemIssueModule {}
