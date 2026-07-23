import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createTransport, Transporter } from 'nodemailer';
import { EmailPort, PasswordChangedEmailInput, PasswordResetEmailInput } from './email.port';

@Injectable()
export class SmtpEmailService extends EmailPort {
  private readonly transporter: Transporter;
  private readonly from: string;

  constructor(config: ConfigService) {
    super();
    this.transporter = createTransport({
      host: config.get<string>('SMTP_HOST') ?? 'localhost',
      port: config.get<number>('SMTP_PORT') ?? 1025,
      secure: false,
    });
    this.from = config.get<string>('EMAIL_FROM') ?? 'AntreIn <no-reply@antrein.local>';
  }

  async sendPasswordReset(input: PasswordResetEmailInput): Promise<void> {
    await this.transporter.sendMail({
      from: this.from,
      to: input.to,
      subject: 'Atur ulang password AntreIn Anda',
      text:
        `Halo ${input.name},\n\n` +
        `Gunakan token berikut untuk mengatur ulang password Anda ` +
        `(berlaku ${input.expiresInMinutes} menit):\n\n${input.token}\n\n` +
        `Abaikan email ini jika Anda tidak meminta pengaturan ulang password.`,
    });
  }

  async sendPasswordChanged(input: PasswordChangedEmailInput): Promise<void> {
    await this.transporter.sendMail({
      from: this.from,
      to: input.to,
      subject: 'Password AntreIn Anda telah diubah',
      text:
        `Halo ${input.name},\n\n` +
        `Password akun AntreIn Anda baru saja diubah dan semua sesi login telah diakhiri. ` +
        `Jika ini bukan Anda, segera atur ulang password Anda.`,
    });
  }
}
