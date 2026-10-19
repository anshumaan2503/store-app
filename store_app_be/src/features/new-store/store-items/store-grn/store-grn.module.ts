import { forwardRef, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { StoreGrn, StoreGrnSchema } from './schemas/store-grn.schema';
import { StoreGrnService } from './store-grn.service';
import { StoreGrnController } from './store-grn.controller';
import { StoreCartModule } from '../store-cart/store-cart.module';
import { StockRefillRequestModule } from '../../../stock-refill-request/stock-refill-request.module';
import { StoreNewItemModule } from '../store-item/store-item.module';

@Module({
  imports: [
    MongooseModule.forFeature(
      [{ name: StoreGrn.name, schema: StoreGrnSchema }],
      'store',
    ),
    forwardRef(() => StoreCartModule),
    forwardRef(() => StockRefillRequestModule),
    forwardRef(() => StoreNewItemModule),
  ],
  controllers: [StoreGrnController],
  providers: [StoreGrnService],
  exports: [StoreGrnService],
})
export class StoreGrnModule {}
