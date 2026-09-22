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
import 'package:event_nu/features/home/widgets/floating_nav_bar.dart';
import 'package:event_nu/shared/widgets/event_nu_logo.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) async =>
      throw UnimplementedError();
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
  FakeDiscoveryRepository({this.events = const <Event>[]}) : super(_UnusedApiClient());

  final List<Event> events;

  @override
  Future<List<Category>> listCategories() async => [
        const Category(id: 'c1', slug: 'music', name: 'Music'),
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
    return Paginated(
      page: 1,
      limit: limit,
      total: events.length,
      hasNext: false,
      items: events,
    );
  }

  @override
  Future<Event> getEvent(String id) async =>
      events.firstWhere((e) => e.id == id, orElse: () => events.first);
}

Event _event(String id, {String? categoryId}) => Event.fromJson({
      'id': id,
      'organizer_id': 'org-1',
      'category_id': categoryId,
      'title': 'Flutter Conf 2026',
      'description': 'A night of talks and beats.',
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
    });

Future<Widget> _app({List<Event> events = const []}) async {
  final storage = InMemoryTokenStorage();
  await storage.write(TokenKeys.accessToken, 'access');
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      discoveryRepositoryProvider.overrideWithValue(
        FakeDiscoveryRepository(events: events),
      ),
    ],
    child: const EventNuApp(),
  );
}

/// Drains pending snackbar timers before the test ends.
Future<void> _flushSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final navBar = find.byType(FloatingNavBar);

  Finder inNav(Finder matching) =>
      find.descendant(of: navBar, matching: matching);

  testWidgets('home app bar carries the brand mark', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(EventNuLogo)),
      findsOneWidget,
    );
  });

  testWidgets('floating nav exposes home, map, camera, saves and profile',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(inNav(find.byIcon(Icons.home_outlined)), findsOneWidget);
    expect(inNav(find.byIcon(Icons.map_outlined)), findsOneWidget);
    expect(inNav(find.byIcon(Icons.photo_camera_outlined)), findsOneWidget);
    expect(inNav(find.byIcon(Icons.bookmark_outline)), findsOneWidget);
    expect(inNav(find.byIcon(Icons.person_outline)), findsOneWidget);
  });

  testWidgets('map slot opens the city map shell', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(inNav(find.byIcon(Icons.map_outlined)));
    await tester.pumpAndSettle();

    expect(find.text('City map'), findsOneWidget);
  });

  testWidgets('profile slot opens the profile shell', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(inNav(find.byIcon(Icons.person_outline)));
    await tester.pumpAndSettle();

    expect(find.text('Your profile'), findsOneWidget);
  });

  testWidgets('camera with a hero event opens the share-moment sheet',
      (tester) async {
    await tester.pumpWidget(await _app(events: [_event('e-1')]));
    await tester.pumpAndSettle();

    await tester.tap(inNav(find.byIcon(Icons.photo_camera_outlined)));
    await tester.pumpAndSettle();

    expect(find.text('Share a moment'), findsOneWidget);
  });

  testWidgets('camera without any event stays honest', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(inNav(find.byIcon(Icons.photo_camera_outlined)));
    await tester.pumpAndSettle();

    expect(find.textContaining('share it'), findsOneWidget);
    await _flushSnackBar(tester);
  });

  testWidgets('hero shows the featured event or falls back to brand copy',
      (tester) async {
    await tester.pumpWidget(await _app(events: [_event('e-1')]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-hero')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-hero')),
        matching: find.textContaining('Flutter Conf'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hero falls back to brand copy when the feed is empty',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('home-hero')),
        matching: find.text('Addis is calling'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stories row renders event stories and opens the event on tap',
      (tester) async {
    await tester.pumpWidget(await _app(events: [_event('e-1')]));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-stories')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-stories')), findsOneWidget);

    final story = find.byKey(const Key('story-e-1'));
    expect(story, findsOneWidget);
    for (var i = 0; i < 8; i++) {
      final rect = tester.getRect(story);
      if (rect.top > 80 && rect.center.dy > 120 && rect.center.dy < 500) break;
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, rect.center.dy < 400 ? 140 : -140),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(story);
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('magazine cards blend category, meta and poster into the feed',
      (tester) async {
    final event = _event('e-1', categoryId: 'c1');
    await tester.pumpWidget(await _app(events: [event]));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('magazine-card-e-1')),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('magazine-card-e-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('magazine-card-e-1')),
        matching: find.text('Music'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('magazine-card-e-1')),
        matching: find.text('Free'),
      ),
      findsOneWidget,
    );
  });
}