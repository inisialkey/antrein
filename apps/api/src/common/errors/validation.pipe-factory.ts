import { BadRequestException, ValidationError, ValidationPipe } from '@nestjs/common';

interface FieldError {
  field: string;
  code: string;
  message: string;
}

function flatten(errors: ValidationError[], parent = ''): FieldError[] {
  return errors.flatMap((error) => {
    const field = parent ? `${parent}.${error.property}` : error.property;
    const own = Object.entries(error.constraints ?? {}).map(([constraint, message]) => ({
      field,
      code: constraint.replace(/([a-z])([A-Z])/g, '$1_$2').toUpperCase(),
      message,
    }));
    return [...own, ...flatten(error.children ?? [], field)];
  });
}

export function createValidationPipe(): ValidationPipe {
  return new ValidationPipe({
    whitelist: true,
    transform: true,
    transformOptions: { enableImplicitConversion: false },
    exceptionFactory: (errors) =>
      new BadRequestException({
        code: 'VALIDATION_FAILED',
        message: 'One or more fields are invalid.',
        details: { fields: flatten(errors) },
      }),
  });
}
