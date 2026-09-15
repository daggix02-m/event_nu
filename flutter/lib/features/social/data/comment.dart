import '../../../core/ext/json_utils.dart';

class Comment {
  const Comment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.body,
    required this.moderationStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final String body;
  final String moderationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json.strOr('id', ''),
      eventId: json.strOr('event_id', ''),
      userId: json.strOr('user_id', ''),
      body: json.strOr('body', ''),
      moderationStatus: json.strOr('moderation_status', ''),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: json.date('updated_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}