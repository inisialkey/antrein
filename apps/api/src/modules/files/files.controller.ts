import {
  ArgumentsHost,
  Body,
  Catch,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  PayloadTooLargeException,
  Post,
  Res,
  UploadedFile,
  UseFilters,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { HttpExceptionFilter } from '../../common/errors/http-exception.filter';
import { CurrentUser } from '../auth/current-user.decorator';
import { Public } from '../auth/public.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { UploadFileDto } from './dto/file.dto';
import { fileTooLarge } from './file.errors';
import { FilesService, MAX_FILE_BYTES, UploadedFile as UploadedFileShape } from './files.service';

/**
 * Multer aborts an oversized upload inside the interceptor, so the handler
 * never runs and cannot map it — this restates it as the contract's code and
 * hands it back to the normal error envelope.
 */
@Catch(PayloadTooLargeException)
class FileTooLargeFilter extends HttpExceptionFilter {
  override catch(_exception: unknown, host: ArgumentsHost): void {
    super.catch(fileTooLarge(MAX_FILE_BYTES), host);
  }
}

@ApiTags('files')
@Controller('files')
export class FilesController {
  constructor(private readonly files: FilesService) {}

  @Post()
  @HttpCode(201)
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'purpose'],
      properties: {
        file: { type: 'string', format: 'binary' },
        purpose: { type: 'string' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload an image (contract §36)' })
  @UseFilters(FileTooLargeFilter)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_FILE_BYTES } }))
  upload(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: UploadFileDto,
    @UploadedFile() file: UploadedFileShape | undefined,
  ): ReturnType<FilesService['upload']> {
    return this.files.upload(principal.userId, dto.purpose, file);
  }

  @Public()
  @Get(':fileId/content')
  @ApiOperation({ summary: 'Serve file bytes (contract §37.1)' })
  async content(@Param('fileId') fileId: string, @Res() res: Response): Promise<void> {
    const { body, mimeType } = await this.files.readContent(fileId);
    // Bypasses the envelope interceptor by design — this route returns bytes.
    res.type(mimeType).set('Cache-Control', 'public, max-age=31536000, immutable').send(body);
  }

  @Delete(':fileId')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete an unattached file (contract §37)' })
  remove(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('fileId') fileId: string,
  ): ReturnType<FilesService['deleteFile']> {
    return this.files.deleteFile(principal.userId, fileId);
  }
}
