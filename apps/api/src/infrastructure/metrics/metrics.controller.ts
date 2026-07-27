import { Controller, Get, Headers, NotFoundException, Res } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiExcludeController } from '@nestjs/swagger';
import type { Response } from 'express';
import { Public } from '../../modules/auth/public.decorator';
import { MetricsService } from './metrics.service';

/**
 * Prometheus scrape endpoint. Off unless METRICS_ENABLED=true; when
 * METRICS_TOKEN is set the scraper must send `Authorization: Bearer <token>`.
 * Wrong/missing auth answers 404 (not 401) so the endpoint's existence is not
 * advertised. @Res bypasses the JSON envelope interceptor — Prometheus wants
 * plain text exposition.
 */
@ApiExcludeController()
@Controller('metrics')
export class MetricsController {
  private readonly token: string | undefined;

  constructor(
    private readonly metrics: MetricsService,
    config: ConfigService,
  ) {
    this.token = config.get<string>('METRICS_TOKEN');
  }

  @Public()
  @Get()
  async scrape(
    @Headers('authorization') authorization: string | undefined,
    @Res() res: Response,
  ): Promise<void> {
    if (!this.metrics.enabled) throw new NotFoundException();
    if (this.token && authorization !== `Bearer ${this.token}`) throw new NotFoundException();
    res.setHeader('Content-Type', this.metrics.contentType);
    res.send(await this.metrics.metricsText());
  }
}
