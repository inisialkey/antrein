import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';

/** api-contract §36. Each value maps to exactly one owning resource column. */
export const FILE_PURPOSES = [
  'customer_avatar',
  'business_logo',
  'business_gallery',
  'staff_avatar',
  'service_image',
] as const;

export type FilePurpose = (typeof FILE_PURPOSES)[number];

export class UploadFileDto {
  @ApiProperty({ enum: FILE_PURPOSES })
  @IsIn(FILE_PURPOSES)
  purpose!: FilePurpose;
}
