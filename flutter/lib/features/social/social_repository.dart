import '../../core/api/api_client.dart';
import '../../core/api/pagination.dart';
import 'data/comment.dart';
import 'data/social_models.dart';

class SocialRepository {
  SocialRepository(this._api);

  final ApiClient _api;

  Future<LikeState> setLike(String eventId, bool liked) async {
    final data = liked
        ? await _api.post('/api/v1/events/$eventId/like')
        : await _api.delete('/api/v1/events/$eventId/like');
    return LikeState.fromJson(data as Map<String, dynamic>);
  }

  Future<SaveState> setSave(String eventId, bool saved, {String? folderId}) async {
    final data = saved
        ? await _api.post('/api/v1/events/$eventId/save', data: {'folder_id': folderId})
        : await _api.delete('/api/v1/events/$eventId/save');
    return SaveState.fromJson(data as Map<String, dynamic>);
  }

  Future<FollowState> setFollow(String organizerId, bool follow) async {
    final data = follow
        ? await _api.post('/api/v1/organizers/$organizerId/follow')
        : await _api.delete('/api/v1/organizers/$organizerId/follow');
    return FollowState.fromJson(data as Map<String, dynamic>);
  }

  Future<Paginated<Comment>> listComments(String eventId, {int page = 1, int limit = 50}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/events/$eventId/comments',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: Comment.fromJson);
  }

  Future<Comment> createComment(String eventId, String body) async {
    final data = await _api.post('/api/v1/events/$eventId/comments', data: {'body': body});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  Future<Paginated<SavedEvent>> mySaves({int page = 1, int limit = 20}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/me/saves',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: SavedEvent.fromJson);
  }
}