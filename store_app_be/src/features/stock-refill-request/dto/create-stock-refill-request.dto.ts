import {
  CreateIndentRaiseDto,
  ReviewIndentRaiseDto,
  UpdateIndentQtyDto,
} from './create-indent-raise.dto';

// Re-export for backward compatibility with existing codebase and imports
export { CreateIndentRaiseDto, ReviewIndentRaiseDto, UpdateIndentQtyDto };

export class CreateStockRefillRequestDto extends CreateIndentRaiseDto {}
export class ReviewStockRefillRequestDto extends ReviewIndentRaiseDto {}
export class UpdateStockRefillRequestDto extends UpdateIndentQtyDto {}

