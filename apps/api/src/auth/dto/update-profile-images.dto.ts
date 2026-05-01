import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

export class UpdateProfileImagesDto {
  /** Sıralı genel kullanılabilir görsel URL’leri (S3); en fazla 9. */
  @IsArray()
  @ArrayMaxSize(9)
  @IsString({ each: true })
  imageUrls!: string[];
}
