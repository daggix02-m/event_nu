import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/pagination.dart';
import 'data/category.dart';
import 'data/event.dart';
import 'data/organizer.dart';
import 'data/venue.dart';
import 'discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(apiClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(discoveryRepositoryProvider).listCategories(),
);

final eventDetailProvider = FutureProvider.family<Event, String>(
  (ref, id) => ref.watch(discoveryRepositoryProvider).getEvent(id),
);

final venueDetailProvider = FutureProvider.family<VenueDetail, String>(
  (ref, id) => ref.watch(discoveryRepositoryProvider).getVenue(id),
);

final organizerProvider = FutureProvider.family<Organizer, String>(
  (ref, id) => ref.watch(discoveryRepositoryProvider).getOrganizer(id),
);

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<Event>>(FeedController.new);

class FeedController extends AsyncNotifier<List<Event>> {
  static const int limit = 20;

  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);

  bool _hasNext = false;
  bool _loadingTail = false;
  int _nextPage = 2;
  String _query = '';
  String? _categoryId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get query => _query;
  String? get categoryId => _categoryId;
  bool get hasMore => _hasNext;

  @override
  Future<List<Event>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final q = _query;
    final c = _categoryId;
    final f = _dateFrom;
    final t = _dateTo;
    final page = await _repo.listEvents(
      query: q,
      categoryId: c,
      dateFrom: f,
      dateTo: t,
      page: 1,
      limit: limit,
    );
    if (_nextPageIs(q, c, f, t)) {
      _hasNext = page.hasNext;
      return page.items;
    }
    return const [];
  }

  bool _nextPageIs(String q, String? c, DateTime? f, DateTime? t) {
    return _query == q && _categoryId == c && _dateFrom == f && _dateTo == t;
  }

  Future<Paginated<Event>> _fetchPage(int page) {
    return _repo.listEvents(
      query: _query,
      categoryId: _categoryId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: page,
      limit: limit,
    );
  }

  void _resetAndRefresh() {
    ref.invalidateSelf();
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query.trim();
    _categoryId = null;
    _dateFrom = null;
    _dateTo = null;
    _resetAndRefresh();
  }

  void setCategory(String? id) {
    if (_categoryId == id) return;
    _categoryId = id;
    _query = '';
    _dateFrom = null;
    _dateTo = null;
    _resetAndRefresh();
  }

  void setDateWindow(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    if (_categoryId != null) _categoryId = null;
    _resetAndRefresh();
  }

  void clearFilters() {
    setQuery('');
  }

  Future<void> loadMore() async {
    if (_hasNext == false || _loadingTail) return;
    _loadingTail = true;
    try {
      final page = await _fetchPage(_nextPage);
      final current = state.value ?? const <Event>[];
      if (_nextPageIs(_query, _categoryId, _dateFrom, _dateTo)) {
        state = AsyncData(List<Event>.of(current)..addAll(page.items));
        _nextPage += 1;
        _hasNext = page.hasNext;
      }
    } finally {
      _loadingTail = false;
    }
  }
}