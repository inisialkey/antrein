import { RateLimitService } from './rate-limit.service';

describe('RateLimitService', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });
  afterEach(() => {
    jest.useRealTimers();
  });

  it('allows up to the limit within the window, then blocks', () => {
    const limiter = new RateLimitService(false);
    for (let i = 0; i < 5; i++) {
      expect(limiter.consume('login', 'ip:email', 5, 60_000)).toBe(true);
    }
    expect(limiter.consume('login', 'ip:email', 5, 60_000)).toBe(false);
  });

  it('frees slots once the window slides past old attempts', () => {
    const limiter = new RateLimitService(false);
    for (let i = 0; i < 5; i++) limiter.consume('login', 'k', 5, 60_000);
    expect(limiter.consume('login', 'k', 5, 60_000)).toBe(false);

    jest.advanceTimersByTime(61_000);
    expect(limiter.consume('login', 'k', 5, 60_000)).toBe(true);
  });

  it('isolates buckets and keys', () => {
    const limiter = new RateLimitService(false);
    for (let i = 0; i < 3; i++) limiter.consume('register', 'ip-a', 3, 60_000);
    expect(limiter.consume('register', 'ip-a', 3, 60_000)).toBe(false);
    expect(limiter.consume('register', 'ip-b', 3, 60_000)).toBe(true);
    expect(limiter.consume('login', 'ip-a', 3, 60_000)).toBe(true);
  });

  it('always allows when disabled', () => {
    const limiter = new RateLimitService(true);
    for (let i = 0; i < 100; i++) {
      expect(limiter.consume('login', 'k', 5, 60_000)).toBe(true);
    }
  });
});
