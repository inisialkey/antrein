import { ProviderWebhookError, SandboxPaymentAdapter, signSandboxWebhook } from './sandbox.adapter';

const SECRET = 'test-secret';

describe('SandboxPaymentAdapter', () => {
  let adapter: SandboxPaymentAdapter;

  beforeEach(() => {
    adapter = new SandboxPaymentAdapter(SECRET);
  });

  it('creates deterministic checkout sessions keyed by payment id', async () => {
    const result = await adapter.createPayment({
      paymentId: 'pay_1',
      amount: 50000,
      currency: 'IDR',
      expiresAt: new Date('2026-08-01T10:00:00Z'),
    });
    expect(result.providerReference).toBe('sbx_pay_1');
    expect(result.checkout).toEqual({
      type: 'redirect_url',
      url: expect.stringContaining('sbx_pay_1') as unknown as string,
    });
  });

  it('rejects non-IDR currencies', async () => {
    await expect(
      adapter.createPayment({
        paymentId: 'pay_1',
        amount: 100,
        currency: 'USD',
        expiresAt: new Date(),
      }),
    ).rejects.toThrow(/currency/i);
  });

  it('fails createPayment once when primed, then recovers', async () => {
    adapter.failNextCreate();
    const input = {
      paymentId: 'pay_2',
      amount: 50000,
      currency: 'IDR',
      expiresAt: new Date(),
    };
    await expect(adapter.createPayment(input)).rejects.toThrow(/unavailable/i);
    await expect(adapter.createPayment(input)).resolves.toMatchObject({
      providerReference: 'sbx_pay_2',
    });
  });

  it('reports simulated status through getPaymentStatus', async () => {
    await adapter.createPayment({
      paymentId: 'pay_3',
      amount: 50000,
      currency: 'IDR',
      expiresAt: new Date(),
    });
    expect((await adapter.getPaymentStatus('sbx_pay_3')).status).toBe('pending');
    adapter.simulateStatus('sbx_pay_3', 'paid');
    const status = await adapter.getPaymentStatus('sbx_pay_3');
    expect(status.status).toBe('paid');
    expect(status.eventId).toContain('sbx_pay_3');
  });

  it('completes refunds synchronously', async () => {
    const refund = await adapter.requestRefund({
      refundId: 'ref_1',
      providerReference: 'sbx_pay_3',
      amount: 10000,
      currency: 'IDR',
    });
    expect(refund).toEqual({ providerReference: 'sbx_rf_ref_1', status: 'refunded' });
  });

  describe('webhook verification and parsing', () => {
    const event = {
      eventId: 'evt_1',
      type: 'payment.paid',
      providerReference: 'sbx_pay_1',
      status: 'paid',
      amount: 50000,
      currency: 'IDR',
      occurredAt: '2026-08-01T09:00:00Z',
    };
    const body = Buffer.from(JSON.stringify(event));

    it('accepts a correctly signed payload', () => {
      const parsed = adapter.verifyAndParseWebhook(body, signSandboxWebhook(body, SECRET));
      expect(parsed).toMatchObject({
        eventId: 'evt_1',
        providerReference: 'sbx_pay_1',
        status: 'paid',
        amount: 50000,
      });
    });

    it('rejects a bad signature', () => {
      expect(() => adapter.verifyAndParseWebhook(body, 'deadbeef')).toThrow(ProviderWebhookError);
    });

    it('rejects a missing signature', () => {
      expect(() => adapter.verifyAndParseWebhook(body, undefined)).toThrow(ProviderWebhookError);
    });

    it('rejects unparseable payloads', () => {
      const junk = Buffer.from('not-json');
      expect(() => adapter.verifyAndParseWebhook(junk, signSandboxWebhook(junk, SECRET))).toThrow(
        ProviderWebhookError,
      );
    });
  });
});
