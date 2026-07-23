import { JwtService } from '@nestjs/jwt';
import { newId } from '../../common/id/id';
import { TokenService, TokenServiceOptions } from './token.service';

const OPTIONS: TokenServiceOptions = {
  accessSecret: 'unit-test-secret-at-least-32-characters!!',
  accessTtlMinutes: 15,
  refreshTtlDays: 30,
  issuer: 'antrein-api',
  audience: 'antrein-mobile',
};

describe('TokenService', () => {
  const service = new TokenService(OPTIONS);
  const userId = newId('usr');
  const sessionId = newId('ses');

  describe('access tokens', () => {
    it('signs and verifies a round trip', () => {
      const { token, expiresAt } = service.signAccessToken(userId, sessionId);
      const drift = Math.abs(expiresAt.getTime() - (Date.now() + 15 * 60_000));
      expect(drift).toBeLessThan(5_000);

      const principal = service.verifyAccessToken(token);
      expect(principal.userId).toBe(userId);
      expect(principal.sessionId).toBe(sessionId);
    });

    it('rejects an expired token with AUTH_ACCESS_TOKEN_EXPIRED', () => {
      const expired = new TokenService({ ...OPTIONS, accessTtlMinutes: -1 });
      const { token } = expired.signAccessToken(userId, sessionId);
      expect(() => service.verifyAccessToken(token)).toThrow(
        expect.objectContaining({
          response: expect.objectContaining({ code: 'AUTH_ACCESS_TOKEN_EXPIRED' }),
        }),
      );
    });

    it('rejects a tampered token', () => {
      const { token } = service.signAccessToken(userId, sessionId);
      const tampered = token.slice(0, -4) + 'AAAA';
      expect(() => service.verifyAccessToken(tampered)).toThrow(
        expect.objectContaining({
          response: expect.objectContaining({ code: 'AUTH_ACCESS_TOKEN_INVALID' }),
        }),
      );
    });

    it('rejects a token with the wrong type claim', () => {
      const foreign = new JwtService({ secret: OPTIONS.accessSecret });
      const token = foreign.sign(
        { sub: userId, sid: sessionId, type: 'refresh' },
        { issuer: OPTIONS.issuer, audience: OPTIONS.audience, expiresIn: '15m' },
      );
      expect(() => service.verifyAccessToken(token)).toThrow(
        expect.objectContaining({
          response: expect.objectContaining({ code: 'AUTH_ACCESS_TOKEN_INVALID' }),
        }),
      );
    });

    it('rejects wrong issuer and audience', () => {
      const foreign = new TokenService({ ...OPTIONS, issuer: 'other-api', audience: 'other-app' });
      const { token } = foreign.signAccessToken(userId, sessionId);
      expect(() => service.verifyAccessToken(token)).toThrow(
        expect.objectContaining({
          response: expect.objectContaining({ code: 'AUTH_ACCESS_TOKEN_INVALID' }),
        }),
      );
    });

    it('rejects alg=none tokens', () => {
      const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
      const payload = Buffer.from(
        JSON.stringify({ sub: userId, sid: sessionId, type: 'access' }),
      ).toString('base64url');
      expect(() => service.verifyAccessToken(`${header}.${payload}.`)).toThrow(
        expect.objectContaining({
          response: expect.objectContaining({ code: 'AUTH_ACCESS_TOKEN_INVALID' }),
        }),
      );
    });
  });

  describe('refresh tokens', () => {
    it('generates sessionId.secret and verifies via stored hash', () => {
      const { token, secretHash, expiresAt } = service.generateRefreshToken(sessionId);
      expect(token.startsWith(`${sessionId}.`)).toBe(true);
      const drift = Math.abs(expiresAt.getTime() - (Date.now() + 30 * 86_400_000));
      expect(drift).toBeLessThan(5_000);

      const parsed = service.parseRefreshToken(token);
      expect(parsed).not.toBeNull();
      expect(parsed!.sessionId).toBe(sessionId);
      expect(service.refreshSecretMatches(parsed!.secret, secretHash)).toBe(true);
      expect(service.refreshSecretMatches('wrong-secret', secretHash)).toBe(false);
    });

    it('returns null for malformed refresh tokens', () => {
      expect(service.parseRefreshToken('no-separator')).toBeNull();
      expect(service.parseRefreshToken('bad_prefix.secret')).toBeNull();
      expect(service.parseRefreshToken(`${sessionId}.`)).toBeNull();
      expect(service.parseRefreshToken('')).toBeNull();
    });
  });
});
