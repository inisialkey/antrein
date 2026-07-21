import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { buildOpenApiDocument } from '../src/openapi';

const OUTPUT = resolve(__dirname, '../../../packages/api-contracts/openapi/antrein-v1.json');

async function main(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });

  const document = buildOpenApiDocument(app);
  mkdirSync(dirname(OUTPUT), { recursive: true });
  writeFileSync(OUTPUT, `${JSON.stringify(document, null, 2)}\n`);
  await app.close();

  process.stdout.write(`OpenAPI written to ${OUTPUT}\n`);
}

void main();
