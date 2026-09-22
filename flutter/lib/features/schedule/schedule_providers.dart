import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/data/event.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/discovery_repository.dart';

/// Time-of-day windows for the schedule filters. Like the web app's "All
/// hours / Daylight / Golden hour / Late night" presets.
enum ScheduleTimeFilter {
  all,
  daylight,
  goldenHour,
  lateNight;
}

final scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, List<Event>>(
  ScheduleController.new,
);

/// Fetches events for a single selected day (via `date_from`/`date_to` on the
/// existing events endpoint) and applies a client-side time-of-day filter.
class ScheduleController extends AsyncNotifier<List<Event>> {
  static const int limit = 50;

  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);

  DateTime _selectedDate = DateTime.now();
  ScheduleTimeFilter _filter = ScheduleTimeFilter.all;
  bool _loadingTail = false;
  bool _hasNext = false;
  int _nextPage = 2;

  DateTime get selectedDate => _selectedDate;
  ScheduleTimeFilter get filter => _filter;
  bool get hasMore => _hasNext;

  @override
  Future<List<Event>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final day = _selectedDate;
    final page = await _repo.listEvents(
      dateFrom: day,
      dateTo: day.add(const Duration(days: 1)),
      page: 1,
      limit: limit,
    );
    _hasNext = page.hasNext;
    return _applyFilter(page.items);
  }

  Future<void> selectDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    if (day == _selectedDate) return;
    _selectedDate = day;
    ref.invalidateSelf();
  }

  Future<void> setFilter(ScheduleTimeFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    ref.invalidateSelf();
  }

  Future<void> loadMore() async {
    if (_hasNext == false || _loadingTail) return;
    _loadingTail = true;
    try {
      final day = _selectedDate;
      final page = await _repo.listEvents(
        dateFrom: day,
        dateTo: day.add(const Duration(days: 1)),
        page: _nextPage,
        limit: limit,
      );
      final current = state.value ?? const <Event>[];
      if (_selectedDate == day) {
        state = AsyncData(List<Event>.of(current)..addAll(_applyFilter(page.items)));
        _nextPage += 1;
        _hasNext = page.hasNext;
      }
    } finally {
      _loadingTail = false;
    }
  }

  List<Event> _applyFilter(List<Event> events) {
    if (_filter == ScheduleTimeFilter.all) return events;
    return events.where((e) => matchesFilter(e.startsAt, _filter)).toList();
  }

  /// Whether [time] falls inside [filter]'s hour window.
  static bool matchesFilter(DateTime time, ScheduleTimeFilter filter) {
    final hour = time.toLocal().hour;
    return switch (filter) {
      ScheduleTimeFilter.all => true,
      ScheduleTimeFilter.daylight => hour >= 6 && hour < 18,
      ScheduleTimeFilter.goldenHour =>
        (hour >= 6 && hour < 9) || (hour >= 16 && hour < 19),
      ScheduleTimeFilter.lateNight => hour >= 21 || hour < 6,
    };
  }
}