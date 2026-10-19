import { forwardRef, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { IndentRaiseController } from './indent-raise.controller';
import { StockRefillRequestController } from './stock-refill-request.controller';
import { IndentRaiseService } from './stock-refill-request.service';
import {
  IndentRaise,
  IndentRaiseSchema,
} from './schemas/stock-refill-request.schema';
import {
  IndentDraft,
  IndentDraftSchema,
} from './schemas/indent-draft.schema';
import {
  StoreNewItem,
  StoreNewItemSchema,
} from '../new-store/store-items/store-item/entities/store-item.schema';
import {
  Counter,
  CounterSchema,
} from '../new-store/common/entities/counter.schema';
import { Rack, RackSchema } from '../new-store/locations/rack/entities/rack.schema';
import {
  ItemRackQty,
  ItemRackQtySchema,
} from '../new-store/locations/rack/entities/item-rack-qty.schema';
import { StoreNewItemModule } from '../new-store/store-items/store-item/store-item.module';

import { StoreCartModule } from '../new-store/store-items/store-cart/store-cart.module';
import { StoreItemIssueModule } from '../new-store/store-items/store-item-issue/store-item-issue.module';
import { StoreNotificationModule } from '../store-notification/store-notification.module';

@Module({
  imports: [
    MongooseModule.forFeature(
      [
        { name: IndentRaise.name, schema: IndentRaiseSchema },
        { name: IndentDraft.name, schema: IndentDraftSchema },
        { name: StoreNewItem.name, schema: StoreNewItemSchema },
        { name: Counter.name, schema: CounterSchema },
        { name: Rack.name, schema: RackSchema },
        { name: ItemRackQty.name, schema: ItemRackQtySchema },
      ],
      'store',
    ),
    forwardRef(() => StoreNewItemModule),
    forwardRef(() => StoreCartModule),
    forwardRef(() => StoreItemIssueModule),
    forwardRef(() => StoreNotificationModule),
  ],
  controllers: [IndentRaiseController, StockRefillRequestController],
  providers: [IndentRaiseService],
  exports: [IndentRaiseService],
})
export class StockRefillRequestModule {}

