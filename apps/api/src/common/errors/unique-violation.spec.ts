import { Prisma } from '../../generated/prisma/client';
import { uniqueViolationTarget } from './unique-violation';

const p2002 = (meta: Record<string, unknown>): Prisma.PrismaClientKnownRequestError =>
  new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
    meta,
  });

describe('uniqueViolationTarget', () => {
  it('reads the constraint from the pg driver adapter shape', () => {
    // Verbatim from a real P2002 under @prisma/adapter-pg — `target` is absent.
    const error = p2002({
      modelName: 'User',
      driverAdapterError: {
        name: 'DriverAdapterError',
        cause: {
          originalCode: '23505',
          originalMessage:
            'duplicate key value violates unique constraint "users_phone_normalized_uq"',
          kind: 'UniqueConstraintViolation',
          constraint: { fields: ['phone_number_normalized'] },
        },
      },
    });

    expect(uniqueViolationTarget(error)).toContain('phone');
    expect(uniqueViolationTarget(error)).not.toContain('email_normalized');
  });

  it('still reads the classic meta.target shape', () => {
    expect(uniqueViolationTarget(p2002({ target: ['email_normalized'] }))).toContain(
      'email_normalized',
    );
  });

  it('returns an empty string for anything that is not a P2002', () => {
    expect(uniqueViolationTarget(new Error('boom'))).toBe('');
    expect(uniqueViolationTarget(undefined)).toBe('');
    expect(
      uniqueViolationTarget(
        new Prisma.PrismaClientKnownRequestError('nope', { code: 'P2025', clientVersion: 'test' }),
      ),
    ).toBe('');
  });
});
