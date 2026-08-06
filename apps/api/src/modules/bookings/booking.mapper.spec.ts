import { BookingWithRelations, toBookingResource } from './booking.mapper';

/** Minimal row shape — the mapper only reads the fields set here. */
function bookingRow(overrides: Partial<BookingWithRelations>): BookingWithRelations {
  return {
    id: 'bkg_1',
    bookingCode: 'ANT-20260806-0001',
    bookingType: 'walk_in',
    status: 'waiting',
    businessId: 'biz_1',
    outletId: 'out_1',
    serviceId: 'svc_1',
    staffId: null,
    customerUserId: null,
    customer: null,
    walkInCustomerName: null,
    walkInPhoneNumber: null,
    scheduledAt: null,
    expectedEndsAt: null,
    paymentOption: 'pay_at_location',
    customerNotes: null,
    internalNotes: null,
    snapshot: null,
    payments: [],
    createdAt: new Date('2026-08-06T01:00:00.000Z'),
    updatedAt: new Date('2026-08-06T01:00:00.000Z'),
    ...overrides,
  } as unknown as BookingWithRelations;
}

describe('toBookingResource', () => {
  it('exposes the walk-in customer to the business view (§65)', () => {
    const row = bookingRow({
      walkInCustomerName: 'Budi',
      walkInPhoneNumber: '+6281234567890',
    });

    expect(toBookingResource(row, { businessView: true }).customer).toEqual({
      id: null,
      name: 'Budi',
      phoneNumber: '+6281234567890',
    });
  });

  it('keeps the walk-in customer out of the customer view', () => {
    const row = bookingRow({ walkInCustomerName: 'Budi' });

    expect(toBookingResource(row).customer).toBeNull();
  });

  it('leaves customer null for a walk-in with no recorded name', () => {
    expect(toBookingResource(bookingRow({}), { businessView: true }).customer).toBeNull();
  });
});
