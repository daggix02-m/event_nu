import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/features/moments/data/moment_models.dart';
import 'package:event_nu/features/moments/event_gallery_screen.dart';
import 'package:event_nu/features/moments/moment_providers.dart';
import 'package:event_nu/features/moments/moment_repository.dart';
import 'package:event_nu/features/moments/share_moment_sheet.dart';

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

class FakeMomentRepository extends MomentRepository {
  FakeMomentRepository() : super(_UnusedApiClient());

  final List<String> shareCalls = [];

  @override
  Future<UploadIntent> createUploadIntent({required String kind, required String contentType, required int sizeBytes}) async =>
      const UploadIntent(id: 'intent-1', kind: 'moment', status: 'pending', uploadUrl: 'https://upload.test/presigned', uploadExpirySeconds: 60);

  @override
  Future<void> uploadToPresigned(String url, List<int> bytes, String contentType) async {}

  @override
  Future<MediaAsset> completeUpload(String mediaId) async => const MediaAsset(id: 'intent-1', kind: 'moment', status: 'ready', variants: []);

  @override
  Future<Moment> shareMoment(String eventId, {required String mediaAssetId, required String caption}) async {
    shareCalls.add(caption);
    return Moment(
      id: 'm-1',
      eventId: eventId,
      userId: 'u-1',
      mediaAssetId: mediaAssetId,
      caption: caption,
      createdAt: DateTime.utc(2026, 10, 1),
    );
  }

  @override
  Future<Paginated<Moment>> eventMoments(String eventId, {int page = 1, int limit = 30}) async =>
      Paginated(page: 1, limit: 30, total: 0, hasNext: false, items: const []);
}

// Tiny 1x1 transparent PNG for Image.memory in tests.
const _kTransparentPng = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x62, 0x00, 0x01, 0x00, 0x01,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x34, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
];

Widget _wrap(Widget child, FakeMomentRepository repo) => ProviderScope(
      overrides: [momentRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher({required this.sheet});

  final Widget sheet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => sheet,
          ),
          child: const Text('Open sheet'),
        ),
      ),
    );
  }
}

void main() {
  group('moment models', () {
    test('MediaVariant.fromJson parses density', () {
      final v = MediaVariant.fromJson(const {
        'variant': 'small',
        'density': '2x',
        'url': 'https://cdn/2x.png',
        'width': 400,
      });
      expect(v.density, '2x');
      expect(v.url, 'https://cdn/2x.png');
    });

    test('MediaAsset.displayUrl picks highest density variant', () {
      const asset = MediaAsset(
        id: '1',
        kind: 'moment',
        status: 'ready',
        variants: [
          MediaVariant(variant: 'small', density: '1x', url: 'https://a/1x.png'),
          MediaVariant(variant: 'large', density: '3x', url: 'https://a/3x.png'),
        ],
      );
      expect(asset.displayUrl, 'https://a/3x.png');
    });

    test('UploadIntent.fromJson parses fields', () {
      final i = UploadIntent.fromJson(const {
        'id': 'i-1',
        'kind': 'avatar',
        'status': 'pending',
        'upload_url': 'https://upload.test',
        'upload_expiry_seconds': 120,
      });
      expect(i.uploadUrl, 'https://upload.test');
      expect(i.uploadExpirySeconds, 120);
    });
  });

  group('share moment sheet', () {
    testWidgets('shows image after picker and posts', (tester) async {
      final repo = FakeMomentRepository();
      await tester.pumpWidget(
        _wrap(
          _SheetLauncher(
            sheet: ShareMomentSheet(
              eventId: 'e-1',
              pickImage: () async =>
                  PickedImage(bytes: Uint8List.fromList(_kTransparentPng), contentType: 'image/png'),
            ),
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Post moment'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A great moment');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final filledBtn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filledBtn.onPressed, isNotNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.shareCalls, ['A great moment']);
      expect(find.byType(SnackBar), findsOneWidget);

      expect(repo.shareCalls, ['A great moment']);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('event gallery', () {
    testWidgets('shows empty state when no moments', (tester) async {
      final repo = FakeMomentRepository();
      await tester.pumpWidget(_wrap(const EventGalleryScreen(eventId: 'e-1'), repo));
      await tester.pumpAndSettle();

      expect(find.text('No moments yet'), findsOneWidget);
    });
  });
}