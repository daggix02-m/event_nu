import 'package:dio/dio.dart';
import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/features/saves/my_saves_screen.dart';
import 'package:event_nu/features/social/data/social_models.dart';
import 'package:event_nu/features/social/social_repository.dart';
import 'package:event_nu/features/social/social_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class FakeFolderRepository extends SocialRepository {
  FakeFolderRepository() : super(_UnusedApiClient());

  List<SaveFolder> folders = [
    const SaveFolder(id: 'f-1', name: 'Concerts'),
    const SaveFolder(id: 'f-2', name: 'Meetups'),
  ];

  List<SavedEvent> saves = [
    SavedEvent.fromJson(const {
      'event_id': 'e-1',
      'folder_id': 'f-1',
      'created_at': '2026-09-01T00:00:00Z',
      'event': {
        'id': 'e-1',
        'title': 'Flutter Conf 2026',
        'starts_at': '2026-10-01T09:00:00Z',
        'status': 'published',
        'is_visible': true,
      },
    }),
    SavedEvent.fromJson(const {
      'event_id': 'e-2',
      'folder_id': 'f-2',
      'created_at': '2026-09-02T00:00:00Z',
      'event': {
        'id': 'e-2',
        'title': 'Go Meetup',
        'starts_at': '2026-10-02T09:00:00Z',
        'status': 'published',
        'is_visible': true,
      },
    }),
    SavedEvent.fromJson(const {
      'event_id': 'e-3',
      'created_at': '2026-09-03T00:00:00Z',
      'event': {
        'id': 'e-3',
        'title': 'Hack Night',
        'starts_at': '2026-10-03T09:00:00Z',
        'status': 'published',
        'is_visible': true,
      },
    }),
  ];

  int createCalls = 0;
  int renameCalls = 0;
  int deleteCalls = 0;
  int setSaveCalls = 0;
  String? lastFolderId;
  String lastFolderName = '';

  @override
  Future<List<SaveFolder>> mySaveFolders() async => List.of(folders);

  @override
  Future<SaveFolder> createSaveFolder(String name) async {
    createCalls++;
    final folder = SaveFolder(id: 'f-${folders.length + 1}', name: name);
    folders.add(folder);
    return folder;
  }

  @override
  Future<SaveFolder> renameSaveFolder(String id, String name) async {
    renameCalls++;
    final index = folders.indexWhere((f) => f.id == id);
    final renamed = SaveFolder(id: id, name: name);
    folders[index] = renamed;
    return renamed;
  }

  @override
  Future<void> deleteSaveFolder(String id) async {
    deleteCalls++;
    folders.removeWhere((f) => f.id == id);
    saves = [
      for (final save in saves)
        if (save.folderId == id) save.copyWith(folderId: null) else save,
    ];
  }

  @override
  Future<SaveState> setSave(String eventId, bool saved, {String? folderId}) async {
    setSaveCalls++;
    final index = saves.indexWhere((s) => s.eventId == eventId);
    if (saved && index >= 0) {
      saves[index] = saves[index].copyWith(folderId: folderId);
      lastFolderId = folderId;
    }
    return SaveState(saved: saved);
  }

  @override
  Future<Paginated<SavedEvent>> mySaves({int page = 1, int limit = 20}) async {
    return Paginated(page: 1, limit: limit, total: saves.length, hasNext: false, items: List.of(saves));
  }
}

Widget _wrap(Widget child, FakeFolderRepository repo) => ProviderScope(
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );

Future<void> _pumpSaves(WidgetTester tester, FakeFolderRepository repo) async {
  await tester.pumpWidget(_wrap(const MySavesScreen(), repo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows empty state when nothing is saved', (tester) async {
    final repo = FakeFolderRepository()..saves = [];
    await _pumpSaves(tester, repo);
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('renders All, Uncategorized, custom folder and New folder chips',
      (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    expect(find.byKey(const ValueKey('folder-chip-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-chip-uncategorized')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-chip-f-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-chip-f-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-chip-new')), findsOneWidget);
  });

  testWidgets('groups saves under Folders and Uncategorized headers by default',
      (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    expect(find.byKey(const ValueKey('section-Folders')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-Uncategorized')), findsOneWidget);
    expect(find.text('Flutter Conf 2026'), findsOneWidget);
    expect(find.text('Go Meetup'), findsOneWidget);
    expect(find.text('Hack Night'), findsOneWidget);
  });

  testWidgets('filters list when a folder chip is selected', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.tap(find.byKey(const ValueKey('folder-chip-f-2')));
    await tester.pumpAndSettle();

    expect(find.text('Go Meetup'), findsOneWidget);
    expect(find.text('Flutter Conf 2026'), findsNothing);
    expect(find.text('Hack Night'), findsNothing);
  });

  testWidgets('filters list to Uncategorized saves', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.tap(find.byKey(const ValueKey('folder-chip-uncategorized')));
    await tester.pumpAndSettle();

    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('Flutter Conf 2026'), findsNothing);
  });

  testWidgets('creates a new folder via the New folder chip', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.tap(find.byKey(const ValueKey('folder-chip-new')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Road trips');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.folders.any((f) => f.name == 'Road trips'), isTrue);
    expect(find.byKey(const ValueKey('folder-chip-f-3')), findsOneWidget);
  });

  testWidgets('renames a folder from the long-press actions', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.longPress(find.byKey(const ValueKey('folder-chip-f-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('folder-action-rename')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Live shows');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.renameCalls, 1);
    expect(repo.folders.first.name, 'Live shows');
  });

  testWidgets('deletes a folder and re-homes its saves', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.longPress(find.byKey(const ValueKey('folder-chip-f-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('folder-action-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete folder?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(find.byKey(const ValueKey('folder-chip-f-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('folder-chip-uncategorized')));
    await tester.pumpAndSettle();
    expect(find.text('Go Meetup'), findsOneWidget);
  });

  testWidgets('moves a save to a folder from the long-press sheet', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.longPress(find.byKey(const ValueKey('save-tile-e-3')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-action-move')));
    await tester.pumpAndSettle();

    expect(find.text('Move to folder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('move-option-f-1')));
    await tester.pumpAndSettle();

    expect(repo.setSaveCalls, 1);
    expect(repo.lastFolderId, 'f-1');
    expect(find.textContaining('Moved to "Concerts"'), findsOneWidget);
  });

  testWidgets('removes a save from the long-press sheet', (tester) async {
    final repo = FakeFolderRepository();
    await _pumpSaves(tester, repo);

    await tester.longPress(find.byKey(const ValueKey('save-tile-e-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-action-remove')));
    await tester.pumpAndSettle();

    expect(repo.setSaveCalls, 1);
    expect(find.byKey(const ValueKey('save-tile-e-1')), findsNothing);
    expect(find.text('Flutter Conf 2026'), findsNothing);
  });
}