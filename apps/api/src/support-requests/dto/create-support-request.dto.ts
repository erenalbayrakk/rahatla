import { CommunicationPreference, SupportCategory } from '@prisma/client';
import {
  IsEnum,
  IsOptional,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

export class CreateSupportRequestDto {
  @IsEnum(SupportCategory)
  category!: SupportCategory;

  @IsString()
  @Length(2, 16)
  languageCode!: string;

  @IsEnum(CommunicationPreference)
  communicationPreference!: CommunicationPreference;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
