import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../data/event.dart';

/// Magazine-style feed card: full-bleed poster with a bottom-to-top gradient,
/// frosted meta chips, and a bold Space-Grotesk headline.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.categoryName});

  final Event event;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
      child: Material(
        key: ValueKey('magazine-card-${event.id}'),
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoute.event(event.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _media(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.5, 1],
                          colors: [
                            Colors.transparent,
                            Color(0x66141217),
                            Color(0xEE141217),
                          ],
                        ),
                      ),
                    ),
                    if (categoryName != null)
                      Positioned(
                        top: AppSpace.sm,
                        left: AppSpace.sm,
                        child: _FrostChip(label: categoryName!),
                      ),
                    Positioned(
                      right: AppSpace.sm,
                      bottom: AppSpace.sm,
                      child: _FrostChip(label: event.priceLabel, accent: event.priceIsFree),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
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

  Widget _media() {
    final url = event.posterUrl ?? event.teaserUrl;
    if (url == null) {
      return Container(
        color: AppColors.surfaceContainerHigh,
        child: const Center(
          child: Icon(Icons.local_activity, color: AppColors.neon, size: 34),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surfaceContainerHigh),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceContainerHigh,
        child: const Center(
          child: Icon(Icons.local_activity, color: AppColors.neon, size: 34),
        ),
      ),
    );
  }
}

class _FrostChip extends StatelessWidget {
  const _FrostChip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.secondary : AppColors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB33B383E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x4719E3FF)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}