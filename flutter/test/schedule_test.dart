import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:event_nu/app/app.dart';
import 'package:event_nu/app/providers.dart';
import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/core/storage/token_storage.dart';
import 'package:event_nu/features/auth/auth_repository.dart';
import 'package:event_nu/features/auth/data/user.dart';
import 'package:event_nu/features/discovery/data/category.dart';
import 'package:event_nu/features/discovery/data/event.dart';
import 'package:event_nu/features/discovery/discovery_providers.dart';
import 'package:event_nu/features/discovery/discovery_repository.dart';
import 'package:event_nu/features/discovery/widgets/event_feed.dart';
import 'package:event_nu/features/schedule/schedule_providers.dart';
import 'package:event_nu/features/schedule/schedule_view.dart';
import 'package:event_nu/features/schedule/widgets/date_rail.dart';
import 'package:event_nu/features/schedule/widgets/time_of_day_filters.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getEnvelope(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) async => throw UnimplementedError();
}

/// Builds an event on 2026-10-01 at [hour] (local) so time-window filtering is
/// deterministic on any test machine timezone.
Event _event(String id, int hour) {
  final starts = DateTime(2026, 10, 1, hour);
  return Event.fromJson({
    'id': id,
    'organizer_id': 'org-1',
    'title': 'Event $id',
    'description': 'desc',
    'poster_url': 'https://img.test/$id.jpg',
    'starts_at': starts.toUtc().toIso8601String(),
    'price_is_free': true,
    'price_display': '',
    'action_type': '',
    'status': 'published',
    'moderation_status': 'approved',
    'like_count': 0,
    'liked_by_me': false,
    'saved_by_me': false,
    'created_at': '2026-09-01T00:00:00Z',
  });
}

class _RecordingRepo extends DiscoveryRepository {
  _RecordingRepo() : super(_UnusedApiClient());

  final windows = <({DateTime? from, DateTime? to})>[];
  final events = [
    _event('a-morning', 8),
    _event('b-noon', 13),
    _event('c-evening', 17),
    _event('d-late-night', 22),
  ];

  @override
  Future<Paginated<Event>> listEvents({
    String? query,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    windows.add((from: dateFrom, to: dateTo));
    return Paginated(page: 1, limit: limit, total: events.length, hasNext: false, items: events);
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(_UnusedApiClient());
  @override
  Future<User> fetchMe() async => User(
        id: 'user-1',
        email: 'dev@eventnu.test',
        username: 'dev',
        role: 'user',
        isVerified: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
  @override
  Future<void> logout({required String refreshToken, required String accessToken}) async {}
}

class _FakeDiscoveryRepository extends DiscoveryRepository {
  _FakeDiscoveryRepository({this.events = const <Event>[]}) : super(_UnusedApiClient());

  final List<Event> events;

  @override
  Future<List<Category>> listCategories() async => const [
        Category(id: 'c1', slug: 'music', name: 'Music'),
      ];

  @override
  Future<Paginated<Event>> listEvents({
    String? query,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    return Paginated(page: 1, limit: limit, total: events.length, hasNext: false, items: events);
  }
}

Future<Widget> _app({List<Event> events = const []}) async {
  final storage = InMemoryTokenStorage();
  await storage.write(TokenKeys.accessToken, 'access');
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      discoveryRepositoryProvider.overrideWithValue(
        _FakeDiscoveryRepository(events: events),
      ),
    ],
    child: const EventNuApp(),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ScheduleController', () {
    test('applies time-of-day filters', () async {
      final repo = _RecordingRepo();
      final container = ProviderContainer(
        overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(scheduleControllerProvider.future);
      expect(container.read(scheduleControllerProvider).value!.length, 4);

      await container
          .read(scheduleControllerProvider.notifier)
          .setFilter(ScheduleTimeFilter.daylight);
      await container.read(scheduleControllerProvider.future);
      expect(
        container.read(scheduleControllerProvider).value!.map((e) => e.id).toSet(),
        {'a-morning', 'b-noon', 'c-evening'},
      );

      await container
          .read(scheduleControllerProvider.notifier)
          .setFilter(ScheduleTimeFilter.goldenHour);
      await container.read(scheduleControllerProvider.future);
      expect(
        container.read(scheduleControllerProvider).value!.map((e) => e.id).toSet(),
        {'a-morning', 'c-evening'},
      );

      await container
          .read(scheduleControllerProvider.notifier)
          .setFilter(ScheduleTimeFilter.lateNight);
      await container.read(scheduleControllerProvider.future);
      expect(container.read(scheduleControllerProvider).value!.single.id, 'd-late-night');

      await container
          .read(scheduleControllerProvider.notifier)
          .setFilter(ScheduleTimeFilter.all);
      await container.read(scheduleControllerProvider.future);
      expect(container.read(scheduleControllerProvider).value!.length, 4);
    });

    test('selectDate fetches a single-day window', () async {
      final repo = _RecordingRepo();
      final container = ProviderContainer(
        overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(scheduleControllerProvider.future);

      final day = DateTime(2026, 11, 5);
      await container.read(scheduleControllerProvider.notifier).selectDate(day);
      await container.read(scheduleControllerProvider.future);

      final window = repo.windows.last;
      expect(window.from, DateTime(2026, 11, 5));
      expect(window.to, DateTime(2026, 11, 6));
    });
  });

  group('home segmented control + schedule view', () {
    testWidgets('discover/schedule toggle swaps the home content', (tester) async {
      await tester.pumpWidget(await _app(events: [_event('e-1', 9)]));
      await tester.pumpAndSettle();

      expect(find.text('Discover, dev'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      // Discover content is shown initially.
      expect(find.byType(EventFeed), findsOneWidget);
      expect(find.byType(DateRail), findsNothing);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRail), findsOneWidget);
      expect(find.byType(TimeOfDayFilters), findsOneWidget);
      expect(find.byType(ScheduleView), findsOneWidget);
      expect(find.byType(EventFeed), findsNothing);
      expect(find.text('All hours'), findsOneWidget);
      expect(find.text('Daylight'), findsOneWidget);
      expect(find.text('Golden hour'), findsOneWidget);
      expect(find.text('Late night'), findsOneWidget);
      expect(find.text('SOON'), findsOneWidget);

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.byType(EventFeed), findsOneWidget);
      expect(find.byType(DateRail), findsNothing);

      // The feed still renders the event card (scroll it into view).
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('magazine-card-e-1')),
        find.byType(EventFeed),
        const Offset(0, -300),
      );
      expect(find.byKey(const ValueKey('magazine-card-e-1')), findsOneWidget);
    });
  });
}