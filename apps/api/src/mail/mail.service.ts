import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { MailConfigService } from './mail-config.service';

@Injectable()
export class MailService {
  private readonly log = new Logger(MailService.name);

  constructor(private readonly mailConfig: MailConfigService) {}

  private buildTransport(
    cfg: Awaited<ReturnType<MailConfigService['resolve']>>,
  ) {
    if (!cfg.host) {
      return null;
    }
    return nodemailer.createTransport({
      host: cfg.host,
      port: cfg.port,
      secure: cfg.secure,
      auth:
        cfg.user && cfg.pass
          ? {
              user: cfg.user,
              pass: cfg.pass,
            }
          : undefined,
    });
  }

  private async send(opts: {
    to: string;
    subject: string;
    text: string;
  }): Promise<void> {
    const cfg = await this.mailConfig.resolve();
    const transport = this.buildTransport(cfg);
    if (!transport) {
      this.log.warn(
        `SMTP sunucusu tanımlı değil; e-posta gönderilmedi. Alıcı: ${opts.to}`,
      );
      this.log.warn(opts.text);
      return;
    }
    await transport.sendMail({
      from: cfg.from,
      to: opts.to,
      subject: opts.subject,
      text: opts.text,
    });
  }

  async sendEmailVerification(
    to: string,
    token: string,
    displayName: string,
  ): Promise<void> {
    const cfg = await this.mailConfig.resolve();
    const verifyUrl = `${cfg.baseUrl}/auth/verify-email?token=${encodeURIComponent(token)}`;
    const text = `Merhaba ${displayName},

Rahatla hesabını doğrulamak için aşağıdaki bağlantıya tıkla (24 saat geçerli):

${verifyUrl}

Bağlantı çalışmazsa bu kodu uygulamadaki e-posta doğrulama ekranına yapıştırabilirsin:

${token}

Teşekkürler,
Rahatla`;
    await this.send({
      to,
      subject: 'Rahatla — e-posta doğrulama',
      text,
    });
  }

  async sendPasswordReset(
    to: string,
    token: string,
    displayName: string,
  ): Promise<void> {
    const text = `Merhaba ${displayName},

Şifre sıfırlama talebin için kodun (1 saat geçerli):

${token}

Rahatla uygulamasında Giriş → Şifremi unuttum akışından bu kodu ve yeni şifreni gir.

Bu talebi sen yapmadıysan bu e-postayı yoksayabilirsin.

Rahatla`;
    await this.send({
      to,
      subject: 'Rahatla — şifre sıfırlama',
      text,
    });
  }
}
