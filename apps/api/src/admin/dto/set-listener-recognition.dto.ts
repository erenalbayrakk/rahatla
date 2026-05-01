import { ArrayMaxSize, IsArray, IsString, MaxLength } from 'class-validator';

export class SetListenerRecognitionDto {
  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @MaxLength(48, { each: true })
  labels!: string[];
}
