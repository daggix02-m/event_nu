import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../discovery/data/event.dart';

/// Compact schedule row: poster thumb, title, date/time, price, and a
/// LIVE/ENDED/SOON status chip. Tapping opens the event detail screen.
class ScheduleEventCard extends StatelessWidget {
  const ScheduleEventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = _statusOf(event);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
      child: Material(
        key: ValueKey('schedule-card-${event.id}'),
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoute.event(event.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(
              children: [
                _thumb(),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.whenLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.priceLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: event.priceIsFree
                              ? AppColors.secondary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                switch (status) {
                  _ScheduleStatus.live =>
                    const StatusChip(label: 'LIVE', color: AppColors.secondary),
                  _ScheduleStatus.ended => const StatusChip(
                      label: 'ENDED',
                      color: AppColors.onSurfaceVariant,
                    ),
                  _ScheduleStatus.soon => const StatusChip(
                      label: 'SOON',
                      color: AppColors.tertiary,
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    final url = event.posterUrl ?? event.teaserUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null
            ? Container(
                color: AppColors.surfaceContainerHigh,
                child: const Icon(
                  Icons.local_activity,
                  color: AppColors.neon,
                  size: 22,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceContainerHigh,
                  child: const Icon(
                    Icons.local_activity,
                    color: AppColors.neon,
                    size: 22,
                  ),
                ),
              ),
      ),
    );
  }
}

enum _ScheduleStatus { live, ended, soon }

_ScheduleStatus _statusOf(Event event) {
  final now = DateTime.now();
  if (event.startsAt.isAfter(now)) return _ScheduleStatus.soon;
  final ends = event.endsAt;
  if (ends == null) return _ScheduleStatus.live;
  return ends.isAfter(now) ? _ScheduleStatus.live : _ScheduleStatus.ended;
}