import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../schedule_providers.dart';

/// Single-select filter chips for the time-of-day window.
class TimeOfDayFilters extends ConsumerWidget {
  const TimeOfDayFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(scheduleControllerProvider);
    final current = ref.read(scheduleControllerProvider.notifier).filter;

    final options = <(ScheduleTimeFilter, String)>[
      (ScheduleTimeFilter.all, 'All hours'),
      (ScheduleTimeFilter.daylight, 'Daylight'),
      (ScheduleTimeFilter.goldenHour, 'Golden hour'),
      (ScheduleTimeFilter.lateNight, 'Late night'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutterMobile,
        0,
        AppSpace.gutterMobile,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          for (final (filter, label) in options) ...[
            ChoiceChip(
              key: ValueKey('filter-$filter'),
              label: Text(label),
              selected: current == filter,
              onSelected: (_) =>
                  ref.read(scheduleControllerProvider.notifier).setFilter(filter),
              selectedColor: AppColors.primaryContainer,
              labelStyle: TextStyle(
                color: current == filter
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}