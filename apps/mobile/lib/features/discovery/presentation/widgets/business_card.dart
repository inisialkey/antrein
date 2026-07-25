import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Discovery list card: logo, name, rating, address, open-now badge, price.
class BusinessCard extends StatelessWidget {
  const BusinessCard({required this.business, required this.onTap, super.key});

  final BusinessSummary business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Dimens.space12.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Dimens.radiusSm.r),
                child: SizedBox.square(
                  dimension: Dimens.thumbnail.r,
                  child: business.logoUrl == null
                      ? ColoredBox(
                          color: scheme.primaryContainer,
                          child: Icon(
                            Icons.content_cut,
                            color: scheme.onPrimaryContainer,
                          ),
                        )
                      : AppNetworkImage(url: business.logoUrl!),
                ),
              ),
              const Gap.horizontal(Dimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (business.address != null) ...[
                      const Gap(Dimens.space4),
                      Text(
                        business.address!,
                        style: context.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Gap(Dimens.space8),
                    Wrap(
                      spacing: Dimens.space8.r,
                      runSpacing: Dimens.space4.r,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (business.ratingAverage != null)
                          _Badge(
                            icon: Icons.star_rounded,
                            color: context.appColors.warning,
                            label: business.ratingAverage!.toStringAsFixed(1),
                          ),
                        if (business.isOpenNow != null)
                          _Badge(
                            icon: Icons.circle,
                            color: business.isOpenNow!
                                ? context.appColors.success
                                : scheme.outline,
                            label: business.isOpenNow!
                                ? l10n.openNow
                                : l10n.closedNow,
                          ),
                        if (business.minimumPrice != null)
                          Text(
                            l10n.startingFrom(business.minimumPrice!.formatted),
                            style: context.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: Dimens.space12.r, color: color),
      const Gap.horizontal(Dimens.space4),
      Text(label, style: context.textTheme.bodySmall),
    ],
  );
}
