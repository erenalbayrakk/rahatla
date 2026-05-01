import { IsBoolean } from 'class-validator';

export class UpdateDiscoverVisibilityDto {
  @IsBoolean()
  visibleInDiscover!: boolean;
}
