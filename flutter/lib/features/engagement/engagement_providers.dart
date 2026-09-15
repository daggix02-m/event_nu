import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/engagement_models.dart';
import 'engagement_repository.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  return EngagementRepository(ref.watch(apiClientProvider));
});

/// The current user's RSVP state for one event; supports toggling.
final rsvpControllerProvider =
    AsyncNotifierProvider.family<RsvpController, RsvpState?, String>(
  RsvpController.new,
);

class RsvpController extends AsyncNotifier<RsvpState?> {
  RsvpController(this.eventId);

  final String eventId;

  EngagementRepository get _repo => ref.read(engagementRepositoryProvider);

  @override
  Future<RsvpState?> build() async => _repo.rsvpState(eventId);

  Future<void> toggle({bool? publicRsvp}) async {
    final next = state.value?.going ?? false
        ? await _repo.cancelRsvp(eventId)
        : await _repo.setRsvp(eventId, publicRsvp: publicRsvp);
    state = AsyncData(next);
    ref.invalidate(myRsvpsControllerProvider);
  }
}

/// Events the user is going to, newest first.
final myRsvpsControllerProvider =
    AsyncNotifierProvider<MyRsvpsController, List<MyRsvp>>(MyRsvpsController.new);

class MyRsvpsController extends AsyncNotifier<List<MyRsvp>> {
  static const _limit = 20;
  bool _hasNext = false;
  bool _loadingTail = false;
  int _nextPage = 2;

  EngagementRepository get _repo => ref.read(engagementRepositoryProvider);

  @override
  Future<List<MyRsvp>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final page = await _repo.myRsvps(page: 1, limit: _limit);
    _hasNext = page.hasNext;
    return page.items;
  }

  Future<void> cancelGoing(String eventId) async {
    try {
      await _repo.cancelRsvp(eventId);
      state = AsyncData(
        List<MyRsvp>.of(state.value ?? const [])..removeWhere((r) => r.eventId == eventId),
      );
    } on Object {
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (!_hasNext || _loadingTail) return;
    _loadingTail = true;
    try {
      final page = await _repo.myRsvps(page: _nextPage, limit: _limit);
      final current = state.value ?? const <MyRsvp>[];
      state = AsyncData(List<MyRsvp>.of(current)..addAll(page.items));
      _nextPage += 1;
      _hasNext = page.hasNext;
    } finally {
      _loadingTail = false;
    }
  }
}

/// The caller's notification inbox, newest first.
final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
  NotificationsController.new,
);

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  static const _limit = 30;
  bool _hasNext = false;
  int _nextPage = 2;

  EngagementRepository get _repo => ref.read(engagementRepositoryProvider);

  @override
  Future<List<NotificationItem>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final page = await _repo.listNotifications(page: 1, limit: _limit);
    _hasNext = page.hasNext;
    return page.items;
  }

  int get unreadCount =>
      state.value?.where((n) => !n.isRead).length ?? 0;

  Future<void> markRead(String id) async {
    try {
      await _repo.markNotificationRead(id);
    } on Object {
      rethrow;
    }
    final items = state.value ?? const <NotificationItem>[];
    state = AsyncData([
      for (final n in items)
        if (n.id == id && n.readAt == null)
          NotificationItem(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          )
        else
          n,
    ]);
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllNotificationsRead();
    } on Object {
      rethrow;
    }
    state = AsyncData([
      for (final n in state.value ?? const <NotificationItem>[])
        if (n.readAt == null)
          NotificationItem(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          )
        else
          n,
    ]);
  }

  Future<void> loadMore() async {
    if (!_hasNext) return;
    final page = await _repo.listNotifications(page: _nextPage, limit: _limit);
    final current = state.value ?? const <NotificationItem>[];
    state = AsyncData(List<NotificationItem>.of(current)..addAll(page.items));
    _nextPage += 1;
    _hasNext = page.hasNext;
  }
}

/// Reviews for one event, newest first; submit writes a new review.
final reviewsControllerProvider =
    AsyncNotifierProvider.family<ReviewsController, List<ReviewItem>, String>(
  ReviewsController.new,
);

class ReviewsController extends AsyncNotifier<List<ReviewItem>> {
  ReviewsController(this.eventId);

  final String eventId;

  EngagementRepository get _repo => ref.read(engagementRepositoryProvider);

  @override
  Future<List<ReviewItem>> build() async {
    final page = await _repo.listReviews(eventId, page: 1, limit: 20);
    return page.items;
  }

  Future<void> submit({required int rating, required String body}) async {
    try {
      await _repo.createReview(eventId, rating: rating, body: body);
    } on Object {
      rethrow;
    }
    ref.invalidateSelf();
  }
}