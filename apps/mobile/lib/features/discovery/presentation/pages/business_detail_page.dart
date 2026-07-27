import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/presentation/pages/slot_picker_page.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/usecases/get_business_profile.dart';
import 'package:antrein/features/discovery/presentation/cubit/business_detail_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Business profile: header + bookable services (api-contract §39–§41).
/// Tapping a service starts the booking flow with a prefilled draft.
class BusinessDetailPage extends StatelessWidget {
  const BusinessDetailPage({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<BusinessDetailCubit>();
      unawaited(cubit.load(businessId));
      return cubit;
    },
    child: const _BusinessDetailView(),
  );
}

class _BusinessDetailView extends StatelessWidget {
  const _BusinessDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<BusinessDetailCubit, BusinessDetailState>(
      builder: (context, state) => AppScaffold(
        appBar: AppBar(
          title: Text(switch (state) {
            BusinessDetailLoaded(:final profile) => profile.detail.name,
            _ => l10n.businessDetailTitle,
          }),
        ),
        body: switch (state) {
          BusinessDetailInitial() ||
          BusinessDetailLoading() => const AppLoading(),
          BusinessDetailError(:final message) => AppEmpty(
            message: message,
            icon: Icons.error_outline,
          ),
          BusinessDetailLoaded(:final profile) => _Loaded(profile: profile),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = profile.detail;
    final outlet = detail.primaryOutlet;
    final services = profile.services
        .where((s) => s.isActive)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.radiusMd.r),
              child: SizedBox.square(
                dimension: Dimens.logo.r * 0.75,
                child: detail.logoUrl == null
                    ? ColoredBox(
                        color: context.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.content_cut,
                          size: Dimens.iconLg.r,
                          color: context.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : AppNetworkImage(url: detail.logoUrl!),
              ),
            ),
            const Gap.horizontal(Dimens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.name, style: context.textTheme.titleLarge),
                  if (detail.ratingAverage != null) ...[
                    const Gap(Dimens.space4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: Dimens.iconSm.r,
                          color: context.appColors.warning,
                        ),
                        const Gap.horizontal(Dimens.space4),
                        Text(
                          l10n.ratingLabel(
                            detail.ratingAverage!.toStringAsFixed(1),
                            '${detail.ratingCount ?? 0}',
                          ),
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  if (outlet?.address != null) ...[
                    const Gap(Dimens.space4),
                    Text(
                      outlet!.address!,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (detail.description != null) ...[
          const Gap(Dimens.space16),
          Text(detail.description!, style: context.textTheme.bodyMedium),
        ],
        if (detail.cancellationPolicySummary != null) ...[
          const Gap(Dimens.space12),
          Container(
            padding: EdgeInsets.all(Dimens.space12.r),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Dimens.radiusSm.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: Dimens.iconSm.r,
                  color: context.appColors.info,
                ),
                const Gap.horizontal(Dimens.space8),
                Expanded(
                  child: Text(
                    detail.cancellationPolicySummary!,
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Gap(Dimens.space24),
        Text(l10n.servicesSection, style: context.textTheme.titleMedium),
        const Gap(Dimens.space8),
        if (services.isEmpty)
          AppEmpty(
            message: l10n.servicesEmpty,
            icon: Icons.design_services_outlined,
          )
        else
          ...services.map(
            (service) => Padding(
              padding: EdgeInsets.only(bottom: Dimens.space12.r),
              child: _ServiceTile(service: service, profile: profile),
            ),
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.profile});

  final ServiceItem service;
  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Dimens.space12.r),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: context.textTheme.titleSmall),
                  const Gap(Dimens.space4),
                  Text(
                    l10n.serviceMeta(
                      '${service.durationMinutes}',
                      service.price.formatted,
                    ),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Gap.horizontal(Dimens.space12),
            AppButton(
              label: l10n.bookAction,
              expanded: false,
              onPressed: () {
                final detail = profile.detail;
                final outlet = detail.primaryOutlet;
                if (outlet == null) return;
                unawaited(
                  context.pushNamed(
                    Routes.bookingSlots.name,
                    extra: SlotPickerArgs(
                      draft: BookingDraft(
                        businessId: detail.id,
                        businessName: detail.name,
                        outlet: outlet,
                        service: service,
                        supportedPaymentOptions: detail.supportedPaymentOptions,
                      ),
                      staff: profile.staff,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
