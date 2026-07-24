import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { EmailPort } from '../../infrastructure/email/email.port';
import { SmtpEmailService } from '../../infrastructure/email/smtp-email.service';
import { AuthController } from './auth.controller';
import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { PasswordHasher } from './password.hasher';
import { PasswordResetService } from './password-reset.service';
import { RateLimitService } from './rate-limit.service';
import { TokenService } from './token.service';

@Module({
  controllers: [AuthController],
  providers: [
    PasswordHasher,
    AuthService,
    PasswordResetService,
    { provide: TokenService, useFactory: TokenService.fromConfig, inject: [ConfigService] },
    { provide: RateLimitService, useFactory: RateLimitService.fromConfig, inject: [ConfigService] },
    { provide: EmailPort, useClass: SmtpEmailService },
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
  exports: [TokenService],
})
export class AuthModule {}
