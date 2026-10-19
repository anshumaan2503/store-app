import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { StoreCart, StoreCartSchema } from './entities/store-cart.schema';
import {
  StoreCartConfig,
  StoreCartConfigSchema,
} from './entities/store-cart-config.schema';
import {
  StoreCartHistory,
  StoreCartHistorySchema,
} from './entities/store-cart-history.schema';
import { StoreCartService } from './store-cart.service';
import { StoreCartGateway } from './store-cart.gateway';
import { StoreCartController } from './store-cart.controller';
import { UserModule } from 'src/features/user/user.module';

@Module({
  imports: [
    MongooseModule.forFeature(
      [
        { name: StoreCart.name, schema: StoreCartSchema },
        { name: StoreCartConfig.name, schema: StoreCartConfigSchema },
        { name: StoreCartHistory.name, schema: StoreCartHistorySchema },
      ],
      'store',
    ),
    UserModule,
  ],
  controllers: [StoreCartController],
  providers: [StoreCartService, StoreCartGateway],
  exports: [StoreCartService, StoreCartGateway],
})
export class StoreCartModule {}
