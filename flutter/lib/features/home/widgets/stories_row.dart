import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../discovery/data/event.dart';

/// Horizontal "stories" rail derived from the discovery feed.
///
/// Each story is an event: a gradient ring around its poster (or initial) with
/// a short title beneath. Tapping opens the event. The whole rail is hidden
/// when there are no events yet.
class StoriesRow extends StatelessWidget {
  const StoriesRow({super.key, required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final stories = events.take(8).toList();
    return Column(
      key: const ValueKey('home-stories'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.marginMobile,
            AppSpace.lg,
            AppSpace.marginMobile,
            AppSpace.sm,
          ),
          child: Text(
            'On the Radar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.marginMobile),
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (context, index) {
              final event = stories[index];
              return _Story(event: event);
            },
          ),
        ),
      ],
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.event});

  final Event event;

  String get _shortTitle {
    final title = event.title.trim();
    return title.length <= 10 ? title : '${title.substring(0, 9)}…';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('story-${event.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(AppRoute.event(event.id)),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryContainer, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatar(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final url = event.teaserUrl ?? event.posterUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _initial(context),
      );
    }
    return _initial(context);
  }

  Widget _initial(BuildContext context) {
    final letter = event.title.trim().isEmpty
        ? '?'
        : event.title.trim().substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.neon,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}