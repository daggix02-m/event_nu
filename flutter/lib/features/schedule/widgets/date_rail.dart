import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../schedule_providers.dart';

/// Horizontal 30-day date scroller (today..+29). The selected date renders as
/// a filled pill; all others as outlined pills.
class DateRail extends ConsumerStatefulWidget {
  const DateRail({super.key});

  @override
  ConsumerState<DateRail> createState() => _DateRailState();
}

class _DateRailState extends ConsumerState<DateRail> {
  static const int dayCount = 30;

  late final ScrollController _scrollController;
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    _days = List.generate(
      dayCount,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selected = ref.read(scheduleControllerProvider.notifier).selectedDate;
      _scrollTo(selected);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(DateTime day) {
    if (!_scrollController.hasClients) return;
    final index = day.difference(_days.first).inDays;
    if (index <= 0 || index >= dayCount) return;
    // Keep the tapped date roughly centered, clamping to the edges.
    const itemWidth = 64.0;
    final offset = (index * itemWidth - 80)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onTap(DateTime day) {
    ref.read(scheduleControllerProvider.notifier).selectDate(day);
    _scrollTo(day);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the controller so the rail rebuilds when the selection changes.
    ref.watch(scheduleControllerProvider);
    final selected = ref.read(scheduleControllerProvider.notifier).selectedDate;

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpace.gutterMobile, 4, AppSpace.gutterMobile, 4),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected =
              day.year == selected.year && day.month == selected.month && day.day == selected.day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DatePill(
              day: day,
              selected: isSelected,
              onTap: () => _onTap(day),
            ),
          );
        },
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.day, required this.selected, required this.onTap});

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final background =
        selected ? AppColors.primaryContainer : AppColors.surfaceContainer;
    final foreground =
        selected ? AppColors.onPrimaryContainer : AppColors.onSurface;

    return InkWell(
      key: ValueKey('date-${day.month}-${day.day}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 56,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(day),
              style: textTheme.labelSmall?.copyWith(
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}