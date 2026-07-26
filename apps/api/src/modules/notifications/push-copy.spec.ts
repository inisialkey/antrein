import { queuePushCopy } from './push-copy';

describe('queuePushCopy', () => {
  it('maps check-in to queue_checked_in with the display number in the body', () => {
    const copy = queuePushCopy('checked_in', 'A012');
    expect(copy.notificationType).toBe('queue_checked_in');
    expect(copy.title).toBe('Check-in berhasil');
    expect(copy.body).toContain('A012');
  });

  it('maps called to queue_called with the display number in the body', () => {
    const copy = queuePushCopy('called', 'A007');
    expect(copy.notificationType).toBe('queue_called');
    expect(copy.title).toBe('Giliran Anda tiba');
    expect(copy.body).toContain('A007');
  });
});
