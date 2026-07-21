import { INestApplication } from '@nestjs/common';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';

export function buildOpenApiDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('AntreIn API')
    .setDescription(
      'Booking, payment, check-in, and real-time queue platform. ' +
        'Human-readable contract: docs/02-api-contract.md',
    )
    .setVersion('v1')
    .addBearerAuth()
    .build();
  return SwaggerModule.createDocument(app, config);
}
