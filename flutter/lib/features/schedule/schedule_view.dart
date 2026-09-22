import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/data/event.dart';
import 'schedule_providers.dart';
import 'widgets/date_rail.dart';
import 'widgets/schedule_event_card.dart';
import 'widgets/time_of_day_filters.dart';

/// Inline schedule body shared by the home segment and the standalone
/// [ScheduleScreen]: date rail, time-of-day filters, and the event list.
class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(scheduleControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DateRail(),
        const TimeOfDayFilters(),
        Expanded(
          child: feed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Couldn't load the schedule. Pull to retry.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            data: (events) => events.isEmpty
                ? _emptyState(context)
                : _scheduleList(events),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 40),
          const SizedBox(height: 8),
          Text(
            'Nothing on this day',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different date or time window.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleList(List<Event> events) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ScheduleEventCard(event: event),
        );
      },
    );
  }
}