import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/api_exception.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/core/sync/sync_engine.dart';
import 'package:event_nu/core/sync/sync_models.dart';
import 'package:event_nu/core/sync/sync_store.dart';
import 'package:event_nu/features/discovery/discovery_providers.dart';
import 'package:event_nu/features/discovery/discovery_repository.dart';
import 'package:event_nu/features/discovery/data/event.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.onSync}) : super(dio: Dio());

  final Map<String, dynamic> Function()? onSync;

  @override
  Future<Map<String, dynamic>> getEnvelope(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path.startsWith('/api/v1/sync')) {
      return {'data': onSync!()};
    }
    throw UnimplementedError();
  }
}

Map<String, dynamic> _eventJson(String id) => {
      'id': id,
      'organizer_id': 'org-1',
      'title': 'Event $id',
      'description': 'desc $id',
      'starts_at': '2026-10-01T18:00:00Z',
      'created_at': '2026-09-01T00:00:00Z',
      'price_is_free': true,
      'action_type': 'rsvp',
      'status': 'published',
      'moderation_status': 'approved',
      'like_count': 0,
      'liked_by_me': false,
      'saved_by_me': false,
    };

class _FakeDiscoveryRepository extends DiscoveryRepository {
  _FakeDiscoveryRepository() : super(_FakeApiClient());

  bool failFeed = false;

  @override
  Future<Paginated<Event>> listEvents({
    String? query,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    if (failFeed) {
      throw const ApiException(code: 'network_error', message: 'offline');
    }
    return Paginated(page: 1, limit: limit, total: 0, hasNext: false, items: const []);
  }
}

void main() {
  group('sync engine', () {
    test('pull applies changes and persists cursor', () async {
      final store = InMemorySyncStore();
      final engine = SyncEngine(
        client: _FakeApiClient(
          onSync: () => {
            'changes': [
              {
                'domain': 'events',
                'op': 'upsert',
                'id': 'e-1',
                'payload': _eventJson('e-1'),
              },
              {'domain': 'events', 'op': 'delete', 'id': 'e-2'},
            ],
            'next_cursor': '2026-09-02T00:00:00Z',
          },
        ),
        store: store,
      );

      await engine.syncOnce();

      final changes = await store.readChanges('events');
      expect(changes, hasLength(2));
      expect(changes.first.domain, 'events');
      expect(changes.first.isDelete, isFalse);
      expect(changes.last.isDelete, isTrue);
      expect(await store.readCursor(), '2026-09-02T00:00:00Z');
    });

    test('SyncData.fromJson tolerates has_more layout', () {
      final data = SyncData.fromJson(const {
        'changes': <dynamic>[],
        'next_cursor': 'c1',
        'has_more': {'events': true},
      });
      expect(data.nextCursor, 'c1');
      expect(data.hasMore['events'], isTrue);
      expect(data.changes, isEmpty);
    });
  });

  group('sync controller', () {
    test('marks offline when pull fails with network error', () async {
      final store = InMemorySyncStore();
      final engine = SyncEngine(
        client: _FakeApiClient(
          onSync: () => throw const ApiException(code: 'network_error', message: 'offline'),
        ),
        store: store,
      );
      final container = ProviderContainer(
        overrides: [
          syncEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(syncStateControllerProvider.future);
      expect(state.offline, isTrue);
    });
  });

  group('offline feed fallback', () {
    test('serves cached synced events when the network is down', () async {
      final store = InMemorySyncStore();
      await store.applyChanges([
        SyncChange(domain: 'events', op: 'upsert', id: 'e-1', payload: _eventJson('e-1')),
        SyncChange(domain: 'events', op: 'upsert', id: 'e-2', payload: _eventJson('e-2')),
      ]);

      final repository = _FakeDiscoveryRepository()..failFeed = true;
      final container = ProviderContainer(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(repository),
          syncStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final events = await container.read(feedControllerProvider.future);
      expect(events, hasLength(2));
      expect(events.first.title, 'Event e-1');
    });
  });
}