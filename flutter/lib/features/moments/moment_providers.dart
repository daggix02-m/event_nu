import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/moment_models.dart';
import 'moment_repository.dart';

final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  return MomentRepository(ref.watch(apiClientProvider));
});

final mediaAssetProvider = FutureProvider.family<MediaAsset, String>(
  (ref, id) => ref.watch(momentRepositoryProvider).media(id),
);

final eventMomentsControllerProvider = AsyncNotifierProvider.family<
    EventMomentsController, List<Moment>, String>(EventMomentsController.new);

class EventMomentsController extends AsyncNotifier<List<Moment>> {
  EventMomentsController(this.eventId);

  final String eventId;
  static const int limit = 30;

  MomentRepository get _repo => ref.read(momentRepositoryProvider);

  bool _hasNext = false;
  bool _loadingTail = false;
  int _nextPage = 2;

  bool get hasMore => _hasNext;

  @override
  Future<List<Moment>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final page = await _repo.eventMoments(eventId, page: 1, limit: limit);
    _hasNext = page.hasNext;
    return page.items;
  }

  Future<void> loadMore() async {
    if (!_hasNext || _loadingTail) return;
    _loadingTail = true;
    try {
      final page = await _repo.eventMoments(eventId, page: _nextPage, limit: limit);
      final current = state.value ?? const <Moment>[];
      state = AsyncData(List<Moment>.of(current)..addAll(page.items));
      _nextPage += 1;
      _hasNext = page.hasNext;
    } finally {
      _loadingTail = false;
    }
  }
}

final shareMomentControllerProvider =
    AsyncNotifierProvider<ShareMomentController, bool>(ShareMomentController.new);

class ShareMomentController extends AsyncNotifier<bool> {
  MomentRepository get _repo => ref.read(momentRepositoryProvider);

  @override
  Future<bool> build() async => false;

  Future<void> share({
    required String eventId,
    required List<int> bytes,
    required String contentType,
    String caption = '',
  }) async {
    final intent = await _repo.createUploadIntent(
      kind: 'moment',
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    await _repo.uploadToPresigned(intent.uploadUrl, bytes, contentType);
    await _repo.completeUpload(intent.id);
    await _repo.shareMoment(
      eventId,
      mediaAssetId: intent.id,
      caption: caption,
    );
    ref.invalidate(eventMomentsControllerProvider(eventId));
  }
}