import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/category.dart';
import '../discovery_providers.dart';
import 'event_card.dart';

/// Renders the discovery feed — the home timeline.
///
/// [headers] are rendered as the first items (the hero, stories rail, category
/// pills, host banner…). Headers and cards bleed edge-to-edge while each
/// header manages its own horizontal padding; the list carries bottom padding
/// equal to [AppSpace.bottomNavClearance] so content can scroll clear of the
/// floating pill nav.
class EventFeed extends ConsumerWidget {
  const EventFeed({super.key, this.headers = const []});

  final List<Widget> headers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoryNames = <String, String>{
      for (final c in categories) c.id: c.name,
    };

    final children = feed.when(
      skipLoadingOnRefresh: true,
      loading: () => [
        ...headers,
        ..._skeletons(),
      ],
      error: (error, _) => [
        ...headers,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
          child: ErrorState(
            message: _friendlyMessage(error),
            onRetry: () => ref.invalidate(feedControllerProvider),
          ),
        ),
      ],
      data: (events) => events.isEmpty
          ? [
              ...headers,
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No events found',
                  message: 'Try widening your search or clearing filters.',
                ),
              ),
            ]
          : [
              ...headers,
              for (final e in events) EventCard(event: e, categoryName: categoryNames[e.categoryId]),
            ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 500) {
          ref.read(feedControllerProvider.notifier).loadMore();
        }
        return true;
      },
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(feedControllerProvider.future),
        child: _FeedList(children: children),
      ),
    );
  }

  static String _friendlyMessage(Object error) {
    if (error is ApiException && error.isUnauthorized) {
      return 'Your session has expired. Sign in again to keep exploring.';
    }
    if (error is ApiException) {
      return error.message;
    }
    return 'Could not load events. Please try again.';
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final child in children) {
      if (items.isNotEmpty) items.add(const SizedBox(height: 12));
      items.add(child);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        0,
        AppSpace.xs,
        0,
        AppSpace.bottomNavClearance,
      ),
      children: items,
    );
  }
}

List<Widget> _skeletons() {
  return List.generate(3, (index) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutterMobile),
      child: _SkeletonCard(),
    );
  });
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(context, width: 220, height: 16),
                const SizedBox(height: 12),
                _bar(context, width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}