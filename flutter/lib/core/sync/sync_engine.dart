import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'sync_models.dart';
import 'sync_store.dart';

const _syncDomains =
    'events,venues,organizers,categories,ticket_types,comments,reviews';

class SyncEngine {
  SyncEngine({required this._client, required this._store});

  final ApiClient _client;
  final SyncStore _store;

  Future<void> syncOnce() async {
    final cursor = await _store.readCursor();
    final envelope = await _client.getEnvelope(
      '/api/v1/sync',
      queryParameters: <String, dynamic>{
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'domains': _syncDomains,
        'limit': 100,
      },
    );
    final data = SyncData.fromJson(envelope['data'] as Map<String, dynamic>);
    if (data.changes.isNotEmpty) await _store.applyChanges(data.changes);
    if (data.nextCursor.isNotEmpty) {
      await _store.writeCursor(data.nextCursor);
    }
  }
}

// --- Providers ---

final syncStoreProvider = Provider<SyncStore>((_) => LazyPrefsSyncStore());

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    client: ref.watch(apiClientProvider),
    store: ref.watch(syncStoreProvider),
  );
});

class SyncState {
  const SyncState({
    this.offline = false,
    this.syncing = false,
    this.lastSyncedAt,
    this.error,
  });

  final bool offline;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final Object? error;
}

class SyncController extends AsyncNotifier<SyncState> {
  SyncEngine get _engine => ref.read(syncEngineProvider);

  @override
  Future<SyncState> build() => _runSync();

  Future<SyncState> _runSync() async {
    try {
      await _engine.syncOnce();
      return SyncState(lastSyncedAt: DateTime.now());
    } on ApiException catch (e) {
      if (e.code == 'network_error') {
        return const SyncState(offline: true, error: null);
      }
      return SyncState(error: e);
    } catch (_) {
      return const SyncState(error: null);
    }
  }

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_runSync);
  }
}

final syncStateControllerProvider =
    AsyncNotifierProvider<SyncController, SyncState>(SyncController.new);