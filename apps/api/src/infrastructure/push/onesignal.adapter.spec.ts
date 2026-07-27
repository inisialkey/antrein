import { OneSignalPushAdapter } from './onesignal.adapter';
import { PushSendInput } from './push-notification.port';

const input: PushSendInput = {
  pushProvider: 'onesignal',
  pushToken: 'sub_abc123',
  title: 'Giliran Anda!',
  body: 'Nomor A012 dipanggil.',
  data: { type: 'queue_called', bookingId: 'bkg_1' },
};

const jsonResponse = (status: number, body: unknown): Response =>
  ({
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(body),
  }) as unknown as Response;

describe('OneSignalPushAdapter', () => {
  let fetchSpy: jest.SpyInstance;
  const adapter = new OneSignalPushAdapter('app-id-1', 'api-key-1');

  beforeEach(() => {
    fetchSpy = jest.spyOn(globalThis, 'fetch');
  });

  afterEach(() => fetchSpy.mockRestore());

  it('POSTs the v2 payload keyed by subscription id and returns the message id', async () => {
    fetchSpy.mockResolvedValue(jsonResponse(200, { id: 'msg_1' }));

    const result = await adapter.send(input);

    expect(result).toEqual({ providerMessageId: 'msg_1' });
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.onesignal.com/notifications');
    expect(init.headers).toMatchObject({ Authorization: 'Key api-key-1' });
    expect(JSON.parse(init.body as string)).toMatchObject({
      app_id: 'app-id-1',
      include_subscription_ids: ['sub_abc123'],
      headings: { en: 'Giliran Anda!' },
      contents: { en: 'Nomor A012 dipanggil.' },
      data: { type: 'queue_called', bookingId: 'bkg_1' },
    });
  });

  it('throws on a non-2xx response so the delivery row records the failure', async () => {
    fetchSpy.mockResolvedValue(jsonResponse(400, { errors: ['App id not found'] }));

    await expect(adapter.send(input)).rejects.toThrow('OneSignal send failed (400)');
  });

  it('throws when OneSignal answers 200 with an errors array', async () => {
    fetchSpy.mockResolvedValue(
      jsonResponse(200, { id: '', errors: ['All included players are not subscribed'] }),
    );

    await expect(adapter.send(input)).rejects.toThrow('OneSignal send failed (200)');
  });

  it('returns null providerMessageId when the accepted send reached no device', async () => {
    fetchSpy.mockResolvedValue(jsonResponse(200, { id: '' }));

    await expect(adapter.send(input)).resolves.toEqual({ providerMessageId: null });
  });
});
