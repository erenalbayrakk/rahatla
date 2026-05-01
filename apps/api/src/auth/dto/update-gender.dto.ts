import { Allow } from 'class-validator';

/** `gender: null` ile kaldırılır. Gövde mutlaka `{ "gender": ... }` içermeli. */
export class UpdateGenderDto {
  @Allow()
  gender?: unknown;
}
