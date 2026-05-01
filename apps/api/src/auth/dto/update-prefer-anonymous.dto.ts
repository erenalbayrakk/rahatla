import { IsBoolean } from 'class-validator';

export class UpdatePreferAnonymousDto {
  @IsBoolean()
  preferAnonymous!: boolean;
}
