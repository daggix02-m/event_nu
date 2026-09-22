import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/features/discovery/data/category.dart';
import 'package:event_nu/features/discovery/data/event.dart';
import 'package:event_nu/features/discovery/discovery_providers.dart';
import 'package:event_nu/features/discovery/discovery_repository.dart';
import 'package:event_nu/features/discovery/widgets/category_shelf_section.dart';

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

class FakeDiscoveryRepository extends DiscoveryRepository {
  FakeDiscoveryRepository() : super(_UnusedApiClient());

  final event = Event.fromJson(const {
    'id': 'e-1',
    'organizer_id': 'org-1',
    'title': 'Flutter Conf 2026',
    'description': 'Awesome conference',
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

  @override
  Future<List<Category>> listCategories() async => const [
        Category(id: 'c1', slug: 'tech', name: 'Tech'),
        Category(id: 'c2', slug: 'music', name: 'Music'),
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
    return Paginated(page: 1, limit: limit, total: 1, hasNext: false, items: [event]);
  }
}

void main() {
  testWidgets('See all pre-filters the feed to the category and opens search',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: CategoryShelfSection()),
        ),
        GoRoute(
          path: '/search',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('search-landed'))),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsWidgets);
    expect(find.text('See all'), findsNWidgets(2));

    // First shelf is the Tech category.
    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();

    expect(find.text('search-landed'), findsOneWidget);
    expect(container.read(feedControllerProvider.notifier).categoryId, 'c1');
  });
}