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

// ─────────────────── stubs ───────────────────

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

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(_UnusedApiClient());
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

class FakeDiscoveryRepository extends DiscoveryRepository {
  FakeDiscoveryRepository() : super(_UnusedApiClient());

  final events = [
    Event.fromJson(const {
      'id': 'e-1',
      'organizer_id': 'org-1',
      'title': 'Flutter Conf 2026',
      'description': 'Awesome conference',
      'poster_url': 'https://img.test/poster.jpg',
      'starts_at': '2026-10-01T09:00:00Z',
      'price_is_free': true,
      'price_display': '',
      'action_type': '',
      'status': 'published',
      'moderation_status': 'approved',
      'like_count': 12,
      'liked_by_me': false,
      'saved_by_me': false,
      'created_at': '2026-09-01T00:00:00Z',
    }),
    Event.fromJson(const {
      'id': 'e-2',
      'organizer_id': 'org-1',
      'title': 'Workshop: SwiftUI',
      'description': 'Hands on',
      'starts_at': '2026-10-02T14:00:00Z',
      'price_is_free': false,
      'price_display': '500 ETB',
      'action_type': '',
      'status': 'published',
      'moderation_status': 'approved',
      'like_count': 0,
      'liked_by_me': false,
      'saved_by_me': true,
      'created_at': '2026-09-01T00:00:00Z',
    }),
  ];

  @override
  Future<Event> getEvent(String id) async {
    return events.firstWhere((e) => e.id == id, orElse: () => events.first);
  }

  @override
  Future<List<Category>> listCategories() async => [
        const Category(id: 'c1', slug: 'tech', name: 'Tech'),
        const Category(id: 'c2', slug: 'music', name: 'Music'),
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
    return Paginated(page: 1, limit: 20, total: events.length, hasNext: false, items: events);
  }
}

// ─────────────────── helpers ───────────────────

Future<Widget> _app() async {
  final storage = InMemoryTokenStorage();
  await storage.write(TokenKeys.accessToken, 'access');
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
    ],
    child: const EventNuApp(),
  );
}

// ─────────────────── tests ───────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ──── Unit parsing ────

  test('Event.fromJson parses full payload', () {
    final e = Event.fromJson(const {
      'id': 'e-1',
      'organizer_id': 'org-1',
      'venue_id': 'v-1',
      'category_id': 'c1',
      'title': 'Test',
      'description': 'desc',
      'starts_at': '2026-10-01T09:00:00Z',
      'ends_at': '2026-10-01T17:00:00Z',
      'price_is_free': false,
      'price_display': '300 ETB',
      'action_type': 'ticket',
      'status': 'published',
      'moderation_status': 'approved',
      'max_attendees': 100,
      'like_count': 5,
      'liked_by_me': true,
      'saved_by_me': false,
      'poster_url': 'https://img.test/poster.jpg',
      'teaser_url': 'https://img.test/teaser.jpg',
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(e.id, 'e-1');
    expect(e.venueId, 'v-1');
    expect(e.priceIsFree, false);
    expect(e.posterUrl, 'https://img.test/poster.jpg');
    expect(e.isPublished, true);
    expect(e.whenLabel, contains('Oct'));
    expect(e.priceLabel, '300 ETB');
  });

  test('Paginated.fromJson extracts pagination fields', () {
    final paged = Paginated.fromJson<Event>(
      {
        'data': [
          const {
            'id': 'e-1',
            'organizer_id': 'org-1',
            'title': 't',
            'description': '',
            'starts_at': '2026-10-01T09:00:00Z',
            'price_is_free': true,
            'price_display': '',
            'action_type': '',
            'status': 'published',
            'moderation_status': 'approved',
            'like_count': 0,
            'liked_by_me': false,
            'saved_by_me': false,
            'created_at': '2026-09-01T00:00:00Z',
          }
        ],
        'pagination': {'page': 2, 'limit': 10, 'total': 40, 'has_next': true},
      },
      parseItem: Event.fromJson,
    );
    expect(paged.page, 2);
    expect(paged.total, 40);
    expect(paged.hasNext, true);
    expect(paged.items.first.id, 'e-1');
  });

  // ──── Widget tests ────

  testWidgets('HomeScreen renders greeting, events and category pills', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('Discover, dev'), findsOneWidget);
    expect(find.text('Flutter Conf 2026'), findsWidgets);
    expect(find.text('Free'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('All'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Tech'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('magazine-card-e-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Flutter Conf 2026'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('magazine-card-e-2')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Workshop: SwiftUI'), findsWidgets);
    expect(find.text('500 ETB'), findsWidgets);
  });

  testWidgets('EventCard navigates to event detail screen', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('magazine-card-e-1'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 8; i++) {
      final rect = tester.getRect(card);
      if (rect.top > 90 && rect.center.dy > 140 && rect.center.dy < 500) break;
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, rect.center.dy < 300 ? 120 : -120),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Venue'), findsNothing); // venueId is null
  });

  testWidgets('SearchScreen renders search field via app', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}