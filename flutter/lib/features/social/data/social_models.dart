import '../../../core/ext/json_utils.dart';

class LikeState {
  const LikeState({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  factory LikeState.fromJson(Map<String, dynamic> json) {
    return LikeState(
      liked: json.boolOr('liked', false),
      likeCount: json.intOr('like_count', 0),
    );
  }
}

class SaveState {
  const SaveState({required this.saved, this.folderId});

  final bool saved;
  final String? folderId;

  factory SaveState.fromJson(Map<String, dynamic> json) {
    return SaveState(
      saved: json.boolOr('saved', false),
      folderId: json.str('folder_id'),
    );
  }
}

class FollowState {
  const FollowState({required this.followerCount, required this.followedByMe});

  final int followerCount;
  final bool followedByMe;

  factory FollowState.fromJson(Map<String, dynamic> json) {
    return FollowState(
      followerCount: json.intOr('follower_count', 0),
      followedByMe: json.boolOr('followed_by_me', false),
    );
  }
}

class SaveFolder {
  const SaveFolder({required this.id, required this.name});

  final String id;
  final String name;

  factory SaveFolder.fromJson(Map<String, dynamic> json) {
    return SaveFolder(id: json.strOr('id', ''), name: json.strOr('name', ''));
  }
}

/// A saved event row. `EventSummary` mirrors the backend's lightweight DTO;
/// the nested `event` is null when the saved event is no longer publicly visible.
class SavedEvent {
  const SavedEvent({
    required this.eventId,
    this.folderId,
    required this.createdAt,
    this.summary,
  });

  final String eventId;
  final String? folderId;
  final DateTime createdAt;
  final EventSummary? summary;

  bool get isVisible => summary?.isVisible ?? false;

  SavedEvent copyWith({Object? folderId = _sentinel}) {
    return SavedEvent(
      eventId: eventId,
      folderId: folderId == _sentinel ? this.folderId : folderId as String?,
      createdAt: createdAt,
      summary: summary,
    );
  }

  static const _sentinel = Object();

  factory SavedEvent.fromJson(Map<String, dynamic> json) {
    final summary = json.object('event');
    return SavedEvent(
      eventId: json.strOr('event_id', ''),
      folderId: json.str('folder_id'),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      summary: summary == null ? null : EventSummary.fromJson(summary),
    );
  }
}

class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.isVisible,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final String status;
  final bool isVisible;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id: json.strOr('id', ''),
      title: json.strOr('title', ''),
      startsAt: json.date('starts_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: json.strOr('status', ''),
      isVisible: json.boolOr('is_visible', true),
    );
  }
}