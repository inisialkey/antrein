import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:antrein/features/discovery/presentation/widgets/business_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Home tab: browse barbershops and start a booking (api-contract §38).
class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<DiscoveryCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const _DiscoveryView(),
  );
}

class _DiscoveryView extends StatefulWidget {
  const _DiscoveryView();

  @override
  State<_DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<_DiscoveryView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.tabHome)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimens.space16.r,
              Dimens.space8.r,
              Dimens.space16.r,
              Dimens.space8.r,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.discoverySearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (value) =>
                  context.read<DiscoveryCubit>().load(query: value.trim()),
            ),
          ),
          Expanded(
            child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
              builder: (context, state) => switch (state) {
                DiscoveryInitial() || DiscoveryLoading() => const AppLoading(),
                DiscoveryEmpty() => AppEmpty(
                  message: l10n.discoveryEmpty,
                  icon: Icons.storefront_outlined,
                ),
                DiscoveryError(:final message) => _ErrorRetry(message: message),
                DiscoveryLoaded(:final businesses) => RefreshIndicator(
                  onRefresh: () => context.read<DiscoveryCubit>().refresh(),
                  child: ListView.separated(
                    padding: EdgeInsets.all(Dimens.space16.r),
                    itemCount: businesses.length,
                    separatorBuilder: (_, _) => const Gap(Dimens.space12),
                    itemBuilder: (context, index) {
                      final business = businesses[index];
                      return BusinessCard(
                        business: business,
                        onTap: () => context.pushNamed(
                          Routes.businessDetail.name,
                          pathParameters: {'businessId': business.id},
                        ),
                      );
                    },
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(Dimens.space24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const Gap(Dimens.space16),
          AppButton(
            label: context.l10n.retry,
            expanded: false,
            onPressed: () => context.read<DiscoveryCubit>().load(),
          ),
        ],
      ),
    ),
  );
}
