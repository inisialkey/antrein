import { Module } from '@nestjs/common';
import { EmailPort } from './email.port';
import { SmtpEmailService } from './smtp-email.service';

@Module({
  providers: [{ provide: EmailPort, useClass: SmtpEmailService }],
  exports: [EmailPort],
})
export class EmailModule {}
