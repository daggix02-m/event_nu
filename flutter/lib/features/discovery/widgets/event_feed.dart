import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/event.dart';
import '../discovery_providers.dart';
import 'event_card.dart';

/// Renders the discovery feed: skeleton on load, empty/error states, and the
/// infinitely-scrolling card list with pull-to-refresh.
class EventFeed extends ConsumerWidget {
  const EventFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    return feed.when(
      skipLoadingOnRefresh: true,
      loading: () => const _SkeletonList(),
      error: (error, _) => ErrorState(
        message: _friendlyMessage(error),
        onRetry: () => ref.invalidate(feedControllerProvider),
      ),
      data: (events) => events.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'No events found',
              message: 'Try widening your search or clearing filters.',
            )
          : _EventList(events: events),
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

class _EventList extends ConsumerStatefulWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  ConsumerState<_EventList> createState() => _EventListState();
}

class _EventListState extends ConsumerState<_EventList> {
  static const _threshold = 500.0;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.extentAfter < _threshold) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(feedControllerProvider);
    final hasNext = ref.read(feedControllerProvider.notifier).hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(feedControllerProvider.future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: widget.events.length + 1,
          separatorBuilder: (_, index) => SizedBox(height: index < widget.events.length ? 12 : 0),
          itemBuilder: (context, index) {
            if (index < widget.events.length) {
              return EventCard(event: widget.events[index]);
            }
            if (!hasNext) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 112,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 180, height: 14, decoration: _bar()),
                const Spacer(),
                Container(width: 120, height: 12, decoration: _bar()),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  BoxDecoration _bar() => BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      );
}