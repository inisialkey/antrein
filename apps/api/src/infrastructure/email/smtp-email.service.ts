import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createTransport, Transporter } from 'nodemailer';
import {
  EmailPort,
  PasswordChangedEmailInput,
  PasswordResetEmailInput,
  StaffInvitationEmailInput,
} from './email.port';

@Injectable()
export class SmtpEmailService extends EmailPort {
  private readonly transporter: Transporter;
  private readonly from: string;

  constructor(config: ConfigService) {
    super();
    // ADR 0045: the deployed stack points at an ESP's SMTP relay. Auth is sent
    // only when SMTP_USER is set, so Mailpit keeps working locally unchanged.
    const user = config.get<string>('SMTP_USER');
    this.transporter = createTransport({
      host: config.get<string>('SMTP_HOST') ?? 'localhost',
      port: config.get<number>('SMTP_PORT') ?? 1025,
      secure: config.get<string>('SMTP_SECURE') === 'true',
      // Credentials never travel in the clear: on the STARTTLS port, refuse to
      // send if the relay does not upgrade. Mailpit (no auth) is unaffected.
      requireTLS: Boolean(user),
      auth: user ? { user, pass: config.get<string>('SMTP_PASSWORD') } : undefined,
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

  async sendStaffInvitation(input: StaffInvitationEmailInput): Promise<void> {
    await this.transporter.sendMail({
      from: this.from,
      to: input.to,
      subject: `Undangan bergabung dengan ${input.businessName} di AntreIn`,
      text:
        `Halo ${input.displayName},\n\n` +
        `Anda diundang untuk bergabung dengan ${input.businessName} sebagai staf di AntreIn.\n\n` +
        `Masuk atau daftar dengan email ini, lalu terima undangan dengan ID berikut di aplikasi:\n\n` +
        `${input.invitationId}\n\n` +
        `Undangan berlaku sampai ${input.expiresAt.toISOString()}.`,
    });
  }
}
