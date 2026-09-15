import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_models.dart';

abstract class SyncStore {
  Future<String?> readCursor();
  Future<void> writeCursor(String cursor);
  Future<List<SyncChange>> readChanges(String domain);
  Future<void> applyChanges(List<SyncChange> changes);
}

class LazyPrefsSyncStore implements SyncStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _cursorKey = 'sync.cursor';
  static String _domainKey(String domain) => 'sync.changes.$domain';

  @override
  Future<String?> readCursor() async => (await _instance).getString(_cursorKey);

  @override
  Future<void> writeCursor(String cursor) async =>
      (await _instance).setString(_cursorKey, cursor);

  @override
  Future<List<SyncChange>> readChanges(String domain) async {
    final raw = (await _instance).getString(_domainKey(domain));
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => SyncChange.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> applyChanges(List<SyncChange> changes) async {
    final byDomain = <String, List<SyncChange>>{};
    for (final c in changes) {
      byDomain.putIfAbsent(c.domain, () => []).add(c);
    }
    final prefs = await _instance;
    for (final entry in byDomain.entries) {
      await prefs.setString(
        _domainKey(entry.key),
        jsonEncode(entry.value.map((c) => c.toJson()).toList()),
      );
    }
  }
}

class InMemorySyncStore implements SyncStore {
  String? _cursor;
  final Map<String, List<SyncChange>> _changes = {};

  @override
  Future<String?> readCursor() async => _cursor;

  @override
  Future<void> writeCursor(String cursor) async => _cursor = cursor;

  @override
  Future<List<SyncChange>> readChanges(String domain) async =>
      _changes[domain] ?? const [];

  @override
  Future<void> applyChanges(List<SyncChange> changes) async {
    for (final c in changes) {
      _changes.putIfAbsent(c.domain, () => []).add(c);
    }
  }

  void clear() {
    _cursor = null;
    _changes.clear();
  }
}
