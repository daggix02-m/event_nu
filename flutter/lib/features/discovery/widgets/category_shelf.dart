import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../discovery/data/category.dart';
import '../../discovery/data/event.dart';

/// Maps category slugs to Material Icons, mirroring the web app's
/// `CATEGORY_ICONS` in `components/home/CategoryEventShelf.tsx`.
IconData _iconForSlug(String slug) {
  return switch (slug) {
    'music' => Icons.music_note_outlined,
    'arts-culture' => Icons.palette_outlined,
    'nightlife' => Icons.nightlight_outlined,
    'food-drink' => Icons.restaurant_outlined,
    'sports-fitness' => Icons.fitness_center_outlined,
    'tech-innovation' => Icons.computer_outlined,
    'family' => Icons.favorite_outline,
    _ => Icons.category_outlined,
  };
}

/// Maps category slugs to tint colors for the icon avatar, mirroring the
/// web app's `CATEGORY_COLORS`.
Color _colorForSlug(String slug) {
  return switch (slug) {
    'music' => const Color(0xFFBB86FC),
    'arts-culture' => const Color(0xFFCF6679),
    'nightlife' => const Color(0xFFFFD54F),
    'food-drink' => const Color(0xFF81C784),
    'sports-fitness' => const Color(0xFF64B5F6),
    'tech-innovation' => const Color(0xFF4DD0E1),
    'family' => const Color(0xFFE57373),
    _ => AppColors.neon,
  };
}

/// A horizontal scroll shelf for a single category, showing a header with
/// icon avatar + name + "See all" pill, and a snap-scroll row of compact
/// event cards.
///
/// Matches the web app's `CategoryEventShelf` component.
class CategoryShelf extends StatelessWidget {
  const CategoryShelf({
    super.key,
    required this.category,
    required this.events,
    this.onSeeAll,
  });

  final Category category;
  final List<Event> events;

  /// Invoked before navigating to search so the caller can pre-filter the
  /// feed to [category].
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final icon = _iconForSlug(category.slug);
    final tintColor = _colorForSlug(category.slug);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
          child: Row(
            children: [
              // Icon avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tintColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 18, color: tintColor),
              ),
              const SizedBox(width: AppSpace.sm),
              // Category name + count
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${events.length})',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // See all pill
              GestureDetector(
                onTap: () {
                  // Pre-filter the feed to this category, then open search.
                  // The search screen renders the same feedControllerProvider
                  // feed, so it immediately reflects the category filter.
                  onSeeAll?.call();
                  context.go(AppRoute.search.path);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.neon,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward, size: 14, color: AppColors.neon),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        // Horizontal scroll track
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, index) => _ShelfCard(event: events[index]),
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final url = event.posterUrl ?? event.teaserUrl;

    return GestureDetector(
      onTap: () => context.go(AppRoute.event(event.id)),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster thumbnail
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: url != null
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const Center(
                        child: Icon(Icons.local_activity, color: AppColors.neon, size: 24),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.local_activity, color: AppColors.neon, size: 24),
                    ),
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // Date + price
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.whenLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  event.priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: event.priceIsFree
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
