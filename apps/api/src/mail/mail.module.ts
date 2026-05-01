import { Module } from '@nestjs/common';
import { MailConfigService } from './mail-config.service';
import { MailService } from './mail.service';

@Module({
  providers: [MailConfigService, MailService],
  exports: [MailConfigService, MailService],
})
export class MailModule {}
