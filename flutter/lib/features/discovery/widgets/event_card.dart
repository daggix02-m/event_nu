import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../../shared/widgets/status_chip.dart';
import '../data/event.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoute.event(event.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 112,
                  height: 96,
                  child: event.posterUrl == null
                      ? _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: event.posterUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _PosterPlaceholder(showIcon: false),
                          errorWidget: (_, _, _) => const _PosterPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.whenLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusChip(label: event.priceLabel),
                        const Spacer(),
                        if (event.likeCount > 0) ...[
                          const Icon(Icons.favorite_border, size: 15, color: AppColors.neon),
                          const SizedBox(width: 3),
                          Text(
                            '${event.likeCount}',
                            style: textTheme.labelMedium?.copyWith(color: AppColors.neon),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({this.showIcon = true});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: showIcon
            ? const Icon(Icons.local_activity, color: AppColors.neon, size: 28)
            : const SizedBox.shrink(),
      ),
    );
  }
}