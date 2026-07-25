import 'package:antrein/core/domain/money.dart';
import 'package:antrein/features/booking/data/models/booking_models.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingModel', () {
    final json = <String, dynamic>{
      'id': 'bkg_1',
      'bookingCode': 'ANT-20260801-0001',
      'status': 'pending_payment',
      'paymentOption': 'full_payment',
      'business': {'id': 'biz_1', 'name': 'Barber One'},
      'outlet': {
        'id': 'out_1',
        'name': 'Main',
        'address': {'formatted': 'Jl. Example No. 10'},
      },
      'service': {
        'id': 'svc_1',
        'name': 'Haircut',
        'durationMinutes': 45,
        'price': {'amount': 50000, 'currency': 'IDR'},
      },
      'staff': {'id': 'stf_1', 'name': 'Andi'},
      'scheduledAt': '2026-08-01T10:00:00+07:00',
      'paymentSummary': {
        'totalAmount': {'amount': 50000, 'currency': 'IDR'},
        'requiredNow': {'amount': 50000, 'currency': 'IDR'},
        'paidAmount': {'amount': 0, 'currency': 'IDR'},
        'remainingAmount': {'amount': 50000, 'currency': 'IDR'},
        'status': 'unpaid',
      },
      'cancellation': {
        'canCancel': true,
        'refundEstimate': {'amount': 50000, 'currency': 'IDR'},
        'deadlineAt': '2026-08-01T04:00:00+07:00',
      },
      'createdAt': '2026-07-25T09:00:00+07:00',
    };

    test('maps the §59 resource to the entity', () {
      final entity = BookingModel.fromJson(json).toEntity();

      expect(entity.id, 'bkg_1');
      expect(entity.status, BookingStatus.pendingPayment);
      expect(entity.businessName, 'Barber One');
      expect(entity.outletAddress, 'Jl. Example No. 10');
      expect(entity.servicePrice, const Money(50000));
      expect(entity.durationMinutes, 45);
      expect(entity.staffName, 'Andi');
      expect(entity.paymentSummary?.remainingAmount, const Money(50000));
      expect(entity.canCancel, isTrue);
      expect(entity.refundEstimate, const Money(50000));
      expect(entity.isAwaitingPayment, isTrue);
    });

    test('unknown status maps to BookingStatus.unknown, never throws', () {
      final entity = BookingModel.fromJson({
        ...json,
        'status': 'teleported',
      }).toEntity();
      expect(entity.status, BookingStatus.unknown);
    });

    test('missing optional blocks fall back to safe defaults', () {
      final entity = BookingModel.fromJson({
        'id': 'bkg_2',
        'bookingCode': 'ANT-20260801-0002',
        'status': 'confirmed',
        'paymentOption': 'pay_at_location',
      }).toEntity();
      expect(entity.businessName, isEmpty);
      expect(entity.servicePrice, const Money(0));
      expect(entity.paymentSummary, isNull);
      expect(entity.canCancel, isFalse);
    });
  });

  group('PaymentModel', () {
    test('exposes the checkout url for pending online payments', () {
      final payment = PaymentModel.fromJson(const {
        'id': 'pay_1',
        'bookingId': 'bkg_1',
        'provider': 'sandbox',
        'status': 'pending',
        'amount': {'amount': 50000, 'currency': 'IDR'},
        'checkout': {
          'type': 'redirect_url',
          'url': 'https://sandbox.example/checkout/sbx_pay_1',
        },
        'expiresAt': '2026-08-01T10:30:00+07:00',
      }).toEntity();

      expect(payment.isPending, isTrue);
      expect(payment.checkoutUrl, contains('sbx_pay_1'));
      expect(payment.amount, const Money(50000));
    });
  });

  group('Money', () {
    test('formats integer IDR with id-ID grouping', () {
      expect(const Money(50000).formatted, 'Rp50.000');
    });
  });
}
