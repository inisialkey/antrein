import { Business, BusinessPolicy, Outlet } from '../../generated/prisma/client';
import { PaymentOptionLabel } from './dto/business.dto';

export interface Money {
  amount: number;
  currency: 'IDR';
}

export const idr = (amount: number): Money => ({ amount, currency: 'IDR' });

export function paymentOptionsOf(policy: BusinessPolicy): PaymentOptionLabel[] {
  const options: PaymentOptionLabel[] = [];
  if (policy.allowPayAtLocation) options.push('pay_at_location');
  if (policy.allowFullPayment) options.push('full_payment');
  if (policy.allowDeposit) options.push('deposit');
  return options;
}

const ratingOf = (b: Business): { average: number; count: number } => ({
  average: Number(b.ratingAverage),
  count: b.ratingCount,
});

const addressOf = (o: Outlet): Record<string, unknown> => ({
  formatted: o.addressFormatted,
  latitude: o.latitude === null ? null : Number(o.latitude),
  longitude: o.longitude === null ? null : Number(o.longitude),
});

/** Human cancellation summary from the policy (contract §39 example wording). */
export function cancellationSummaryOf(policy: BusinessPolicy): string {
  const hours = Math.round(policy.fullRefundBeforeMinutes / 60);
  return `Full refund is available until ${hours} hours before the appointment.`;
}

export function toBusinessSummary(
  business: Business & { policy: BusinessPolicy | null; outlets: Outlet[] },
  priceRange: { minimum: number; maximum: number } | null,
): Record<string, unknown> {
  const outlet = business.outlets[0];
  return {
    id: business.id,
    name: business.name,
    slug: business.slug,
    logoUrl: null, // files module pending
    coverImageUrl: null,
    rating: ratingOf(business),
    primaryOutlet: outlet
      ? {
          id: outlet.id,
          name: outlet.name,
          address: addressOf(outlet),
          timezone: outlet.timezone,
          // ponytail: computed from outlet_operating_hours once scheduling (M5) lands.
          isOpenNow: false,
        }
      : null,
    priceRange: priceRange
      ? { minimum: idr(priceRange.minimum), maximum: idr(priceRange.maximum) }
      : null,
    supportedPaymentOptions: business.policy ? paymentOptionsOf(business.policy) : [],
  };
}

export function toBusinessDetails(
  business: Business & { policy: BusinessPolicy | null; outlets: Outlet[] },
): Record<string, unknown> {
  const policy = business.policy;
  return {
    id: business.id,
    name: business.name,
    slug: business.slug,
    description: business.description,
    logoUrl: null,
    gallery: [], // files module pending
    status: business.status,
    rating: ratingOf(business),
    supportedPaymentOptions: policy ? paymentOptionsOf(policy) : [],
    bookingPolicy: policy
      ? {
          minimumLeadMinutes: policy.minimumLeadMinutes,
          maximumAdvanceDays: policy.maximumAdvanceDays,
          automaticConfirmation: policy.automaticConfirmation,
        }
      : null,
    cancellationPolicy: policy ? { summary: cancellationSummaryOf(policy) } : null,
    outlets: business.outlets.map((o) => ({
      id: o.id,
      name: o.name,
      phoneNumber: o.phoneNumber,
      address: addressOf(o),
      timezone: o.timezone,
      // ponytail: empty until scheduling (M5) persists outlet_operating_hours.
      operatingHours: [],
    })),
    createdAt: business.createdAt.toISOString(),
    updatedAt: business.updatedAt.toISOString(),
  };
}

export function toManagementResponse(
  business: Business & { policy: BusinessPolicy | null },
): Record<string, unknown> {
  const policy = business.policy;
  return {
    id: business.id,
    name: business.name,
    description: business.description,
    status: business.status,
    logoUrl: null,
    timezone: business.timezone,
    supportedPaymentOptions: policy ? paymentOptionsOf(policy) : [],
    bookingPolicy: policy
      ? {
          minimumLeadMinutes: policy.minimumLeadMinutes,
          maximumAdvanceDays: policy.maximumAdvanceDays,
          automaticConfirmation: policy.automaticConfirmation,
          maxActiveBookingsPerCustomer: 3, // ADR 0034 fixed in MVP
          checkInEarlyMinutes: policy.checkInEarlyMinutes,
          checkInLateMinutes: policy.checkInLateMinutes,
        }
      : null,
    depositPolicy: policy
      ? {
          enabled: policy.allowDeposit,
          defaultType: policy.defaultDepositType,
          defaultValue: policy.defaultDepositValue,
        }
      : null,
    cancellationPolicy: policy
      ? {
          fullRefundBeforeMinutes: policy.fullRefundBeforeMinutes,
          partialRefundBeforeMinutes: policy.partialRefundBeforeMinutes,
          partialRefundPercentage: policy.partialRefundPercentage,
          noShowRefundPercentage: policy.noShowRefundPercentage,
        }
      : null,
    createdAt: business.createdAt.toISOString(),
    updatedAt: business.updatedAt.toISOString(),
  };
}

export function toOutletResponse(outlet: Outlet): Record<string, unknown> {
  return {
    id: outlet.id,
    businessId: outlet.businessId,
    name: outlet.name,
    phoneNumber: outlet.phoneNumber,
    timezone: outlet.timezone,
    address: addressOf(outlet),
    updatedAt: outlet.updatedAt.toISOString(),
  };
}
