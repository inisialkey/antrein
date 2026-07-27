import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { collectDefaultMetrics, Counter, Registry } from 'prom-client';

/**
 * Prometheus counters (booking-payment §79, realtime-queue §61). Counters are
 * label-free flat names per the docs; high-cardinality resource ids never
 * become labels. Incrementing never throws — metrics must not break a
 * business mutation.
 */
@Injectable()
export class MetricsService {
  readonly enabled: boolean;
  private readonly registry = new Registry();
  private readonly counters = new Map<string, Counter>();

  constructor(config: ConfigService) {
    this.enabled = config.get<string>('METRICS_ENABLED') === 'true';
    if (this.enabled) collectDefaultMetrics({ register: this.registry });
  }

  inc(name: string, value = 1): void {
    try {
      let counter = this.counters.get(name);
      if (!counter) {
        counter = new Counter({ name, help: name, registers: [this.registry] });
        this.counters.set(name, counter);
      }
      counter.inc(value);
    } catch {
      // ponytail: swallow — a bad metric name must never fail the caller.
    }
  }

  metricsText(): Promise<string> {
    return this.registry.metrics();
  }

  get contentType(): string {
    return this.registry.contentType;
  }
}
