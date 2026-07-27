import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:antrein/features/reports/domain/usecases/get_daily_summary.dart';
import 'package:antrein/features/reports/presentation/cubit/daily_summary_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDailySummary extends Mock implements GetDailySummary {}

void main() {
  late MockGetDailySummary getDailySummary;

  const summary = DailySummary(
    date: '2026-07-26',
    totalBookings: 7,
    confirmed: 2,
    waiting: 1,
    inService: 1,
    completed: 1,
    cancelled: 1,
    noShow: 1,
    queueActive: 2,
    averageWaitMinutes: 10,
    grossPaid: Money(150000),
    pendingPayments: Money(75000),
    refunded: Money(25000),
  );

  setUpAll(() {
    registerFallbackValue(
      const GetDailySummaryParams(businessId: '', outletId: ''),
    );
  });

  setUp(() => getDailySummary = MockGetDailySummary());

  blocTest<DailySummaryCubit, DailySummaryState>(
    'emits loading then success with the summary',
    build: () => DailySummaryCubit(getDailySummary),
    setUp: () => when(
      () => getDailySummary(any()),
    ).thenAnswer((_) async => const Right(summary)),
    act: (cubit) => cubit.load(businessId: 'biz_1', outletId: 'out_1'),
    expect: () => [
      const DailySummaryState(status: DailySummaryStatus.loading),
      const DailySummaryState(
        status: DailySummaryStatus.success,
        summary: summary,
      ),
    ],
    verify: (_) {
      final params =
          verify(
                () => getDailySummary(captureAny()),
              ).captured.single
              as GetDailySummaryParams;
      expect(params.businessId, 'biz_1');
      expect(params.outletId, 'out_1');
      expect(params.date, isNull);
    },
  );

  blocTest<DailySummaryCubit, DailySummaryState>(
    'emits failure with the message on error',
    build: () => DailySummaryCubit(getDailySummary),
    setUp: () => when(() => getDailySummary(any())).thenAnswer(
      (_) async => const Left(ServerFailure('Not a member.')),
    ),
    act: (cubit) => cubit.load(businessId: 'biz_1', outletId: 'out_1'),
    expect: () => [
      const DailySummaryState(status: DailySummaryStatus.loading),
      const DailySummaryState(
        status: DailySummaryStatus.failure,
        message: 'Not a member.',
      ),
    ],
  );

  blocTest<DailySummaryCubit, DailySummaryState>(
    'changeDate refetches with the picked date',
    build: () => DailySummaryCubit(getDailySummary),
    setUp: () => when(
      () => getDailySummary(any()),
    ).thenAnswer((_) async => const Right(summary)),
    act: (cubit) async {
      await cubit.load(businessId: 'biz_1', outletId: 'out_1');
      await cubit.changeDate('2026-07-25');
    },
    verify: (_) {
      final dates = verify(
        () => getDailySummary(captureAny()),
      ).captured.cast<GetDailySummaryParams>().map((p) => p.date).toList();
      expect(dates, [null, '2026-07-25']);
    },
  );
}
