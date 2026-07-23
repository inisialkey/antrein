import { Body, Controller, HttpCode, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { AuthService, RequestContext } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import {
  ForgotPasswordDto,
  LoginDto,
  LogoutDto,
  RefreshDto,
  RegisterDto,
  ResetPasswordDto,
} from './dto/auth.dto';
import { PasswordResetService } from './password-reset.service';
import { Public } from './public.decorator';
import { AccessTokenPrincipal } from './token.service';

function contextOf(req: Request): RequestContext {
  return { ip: req.ip, userAgent: req.header('user-agent') };
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly passwordReset: PasswordResetService,
  ) {}

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Register a new customer account' })
  register(@Body() dto: RegisterDto, @Req() req: Request): ReturnType<AuthService['register']> {
    return this.auth.register(dto, contextOf(req));
  }

  @Public()
  @Post('login')
  @HttpCode(200)
  @ApiOperation({ summary: 'Log in with email and password' })
  login(@Body() dto: LoginDto, @Req() req: Request): ReturnType<AuthService['login']> {
    return this.auth.login(dto, contextOf(req));
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Rotate the refresh token and issue a new token pair' })
  refresh(@Body() dto: RefreshDto, @Req() req: Request): ReturnType<AuthService['refresh']> {
    return this.auth.refresh(dto, contextOf(req));
  }

  @Post('logout')
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Log out the current session' })
  logout(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: LogoutDto,
  ): ReturnType<AuthService['logout']> {
    return this.auth.logout(principal, dto);
  }

  @Public()
  @Post('password/forgot')
  @HttpCode(200)
  @ApiOperation({ summary: 'Request a password reset email' })
  forgot(
    @Body() dto: ForgotPasswordDto,
    @Req() req: Request,
  ): ReturnType<PasswordResetService['requestReset']> {
    return this.passwordReset.requestReset(dto, contextOf(req));
  }

  @Public()
  @Post('password/reset')
  @HttpCode(200)
  @ApiOperation({ summary: 'Complete a password reset with a token' })
  reset(
    @Body() dto: ResetPasswordDto,
    @Req() req: Request,
  ): ReturnType<PasswordResetService['resetPassword']> {
    return this.passwordReset.resetPassword(dto, contextOf(req));
  }
}
