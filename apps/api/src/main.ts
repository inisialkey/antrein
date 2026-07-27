import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './infrastructure/realtime/redis-io.adapter';
import { buildOpenApiDocument } from './openapi';

async function bootstrap(): Promise<void> {
  // rawBody: webhook signature verification hashes the exact bytes received.
  const app = await NestFactory.create(AppModule, { rawBody: true });

  app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
  app.enableShutdownHooks();

  // §50: REDIS_URL turns on cross-instance WebSocket fan-out; failure degrades
  // to the in-memory adapter instead of blocking boot (REST stays authoritative).
  const redisUrl = process.env.REDIS_URL;
  if (redisUrl) {
    const redisAdapter = new RedisIoAdapter(app);
    try {
      await redisAdapter.connectToRedis(redisUrl);
      app.useWebSocketAdapter(redisAdapter);
    } catch (error) {
      new Logger('bootstrap').error(
        `Redis Socket.IO adapter unavailable — falling back to in-memory fan-out: ${(error as Error).message}`,
      );
    }
  }

  if (process.env.NODE_ENV !== 'production') {
    SwaggerModule.setup('docs', app, buildOpenApiDocument(app));
  }

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
