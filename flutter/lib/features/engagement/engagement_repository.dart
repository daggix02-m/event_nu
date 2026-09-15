import '../../core/api/api_client.dart';
import '../../core/api/pagination.dart';
import 'data/engagement_models.dart';

class EngagementRepository {
  EngagementRepository(this._api);

  final ApiClient _api;

  Future<RsvpState> rsvpState(String eventId) async {
    final data = await _api.get('/api/v1/events/$eventId/rsvp');
    return RsvpState.fromJson(data as Map<String, dynamic>);
  }

  Future<RsvpState> setRsvp(String eventId, {bool? publicRsvp}) async {
    final data = await _api.post(
      '/api/v1/events/$eventId/rsvp',
      data: publicRsvp == null ? null : {'public_rsvp': publicRsvp},
    );
    return RsvpState.fromJson(data as Map<String, dynamic>);
  }

  Future<RsvpState> cancelRsvp(String eventId) async {
    final data = await _api.delete('/api/v1/events/$eventId/rsvp');
    return RsvpState.fromJson(data as Map<String, dynamic>);
  }

  Future<Paginated<MyRsvp>> myRsvps({int page = 1, int limit = 20}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/me/rsvps',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: MyRsvp.fromJson);
  }

  Future<Paginated<NotificationItem>> listNotifications({int page = 1, int limit = 30}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/notifications',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: NotificationItem.fromJson);
  }

  Future<void> markNotificationRead(String id) async {
    await _api.post('/api/v1/notifications/$id/read');
  }

  Future<int> markAllNotificationsRead() async {
    final data = await _api.post('/api/v1/notifications/read-all');
    final updated = (data as Map<String, dynamic>)['updated'];
    return updated is int ? updated : 0;
  }

  Future<Paginated<ReviewItem>> listReviews(String eventId, {int page = 1, int limit = 20}) async {
    final envelope = await _api.getEnvelope(
      '/api/v1/events/$eventId/reviews',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return Paginated.fromJson(envelope, parseItem: ReviewItem.fromJson);
  }

  Future<ReviewItem> createReview(String eventId, {required int rating, String body = ''}) async {
    final data = await _api.post(
      '/api/v1/events/$eventId/reviews',
      data: <String, dynamic>{'rating': rating, 'body': body},
    );
    return ReviewItem.fromJson(data as Map<String, dynamic>);
  }

  /// `entityType` maps to the URL segment: event, user, venue, comment.
  Future<ReportResult> report(String entityType, String entityId, {required String reasonCode, String description = ''}) async {
    final data = await _api.post(
      '/api/v1/$entityType/$entityId/report',
      data: <String, dynamic>{'reason_code': reasonCode, 'description': description},
    );
    return ReportResult.fromJson(data as Map<String, dynamic>);
  }
}