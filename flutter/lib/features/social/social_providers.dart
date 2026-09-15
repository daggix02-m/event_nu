import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/comment.dart';
import 'data/social_models.dart';
import 'social_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(apiClientProvider));
});

/// Comments for one event, newest first; supports creating new comments.
final commentsControllerProvider =
    AsyncNotifierProvider.family<CommentsController, List<Comment>, String>(
  CommentsController.new,
);

class CommentsController extends AsyncNotifier<List<Comment>> {
  CommentsController(this.eventId);

  final String eventId;

  static const _limit = 50;
  bool _hasNext = false;
  int _nextPage = 2;

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  @override
  Future<List<Comment>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final page = await _repo.listComments(eventId, page: 1, limit: _limit);
    _hasNext = page.hasNext;
    return page.items;
  }

  Future<void> add(String body) async {
    if (body.trim().isEmpty) return;
    final comment = await _repo.createComment(eventId, body.trim());
    state = AsyncData([comment, ...state.value ?? const <Comment>[]]);
  }

  Future<void> loadMore() async {
    if (!_hasNext) return;
    final page = await _repo.listComments(eventId, page: _nextPage, limit: _limit);
    final current = state.value ?? const <Comment>[];
    state = AsyncData(List<Comment>.of(current)..addAll(page.items));
    _nextPage += 1;
    _hasNext = page.hasNext;
  }
}

/// The current user's saved events, ordered newest first.
final mySavesControllerProvider = AsyncNotifierProvider<MySavesController, List<SavedEvent>>(
  MySavesController.new,
);

class MySavesController extends AsyncNotifier<List<SavedEvent>> {
  static const _limit = 20;
  bool _hasNext = false;
  bool _loadingTail = false;
  int _nextPage = 2;

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  @override
  Future<List<SavedEvent>> build() async {
    _nextPage = 2;
    _hasNext = false;
    final page = await _repo.mySaves(page: 1, limit: _limit);
    _hasNext = page.hasNext;
    return page.items;
  }

  Future<void> unsave(String eventId) async {
    await _repo.setSave(eventId, false);
    state = AsyncData(
      List<SavedEvent>.of(state.value ?? const [])..removeWhere((s) => s.eventId == eventId),
    );
  }

  Future<void> loadMore() async {
    if (!_hasNext || _loadingTail) return;
    _loadingTail = true;
    try {
      final page = await _repo.mySaves(page: _nextPage, limit: _limit);
      final current = state.value ?? const <SavedEvent>[];
      state = AsyncData(List<SavedEvent>.of(current)..addAll(page.items));
      _nextPage += 1;
      _hasNext = page.hasNext;
    } finally {
      _loadingTail = false;
    }
  }
}