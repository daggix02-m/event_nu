import '../../../core/ext/json_utils.dart';
import '../../social/data/social_models.dart' show EventSummary;

class RsvpState {
  const RsvpState({required this.going, this.status, this.createdAt});

  final bool going;
  final String? status;
  final DateTime? createdAt;

  factory RsvpState.fromJson(Map<String, dynamic> json) {
    return RsvpState(
      going: json.boolOr('going', false),
      status: json.str('status'),
      createdAt: json.date('created_at'),
    );
  }
}

class MyRsvp {
  const MyRsvp({
    required this.eventId,
    required this.status,
    this.publicRsvp = true,
    this.createdAt,
    this.summary,
  });

  final String eventId;
  final String status;
  final bool publicRsvp;
  final DateTime? createdAt;
  final EventSummary? summary;

  bool get isVisible => summary?.isVisible ?? false;

  factory MyRsvp.fromJson(Map<String, dynamic> json) {
    final summary = json.object('event');
    return MyRsvp(
      eventId: json.strOr('event_id', ''),
      status: json.strOr('status', ''),
      publicRsvp: json.boolOr('public_rsvp', true),
      createdAt: json.date('created_at'),
      summary: summary == null ? null : EventSummary.fromJson(summary),
    );
  }
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.rating,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final int rating;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json.strOr('id', ''),
      eventId: json.strOr('event_id', ''),
      userId: json.strOr('user_id', ''),
      rating: json.intOr('rating', 0),
      body: json.strOr('body', ''),
      status: json.strOr('status', ''),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: json.date('updated_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json.strOr('id', ''),
      type: json.strOr('type', ''),
      title: json.strOr('title', ''),
      body: json.strOr('body', ''),
      data: json.object('data') ?? const {},
      readAt: json.date('read_at'),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ReportResult {
  const ReportResult({required this.reported});

  final bool reported;

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    return ReportResult(reported: json.boolOr('reported', false));
  }
}