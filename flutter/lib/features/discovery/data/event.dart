import 'package:intl/intl.dart';

import '../../../core/ext/json_utils.dart';

class Event {
  const Event({
    required this.id,
    required this.organizerId,
    this.venueId,
    this.categoryId,
    required this.title,
    required this.description,
    required this.startsAt,
    this.endsAt,
    required this.priceIsFree,
    required this.priceDisplay,
    required this.actionType,
    required this.status,
    required this.moderationStatus,
    this.maxAttendees,
    required this.likeCount,
    required this.likedByMe,
    required this.savedByMe,
    this.savedFolderId,
    this.posterUrl,
    this.teaserUrl,
    required this.createdAt,
  });

  final String id;
  final String organizerId;
  final String? venueId;
  final String? categoryId;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool priceIsFree;
  final String priceDisplay;
  final String actionType;
  final String status;
  final String moderationStatus;
  final int? maxAttendees;
  final int likeCount;
  final bool likedByMe;
  final bool savedByMe;
  final String? savedFolderId;
  final String? posterUrl;
  final String? teaserUrl;
  final DateTime createdAt;

  bool get isPublished => status == 'published' && moderationStatus == 'approved';

  /// Human label like "Today, 6:30 PM" / "Sat, Sep 20" for the feed.
  String get whenLabel {
    final now = DateTime.now();
    final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    final time = DateFormat.jm().format(startsAt.toLocal());
    final date = switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => DateFormat('EEE, MMM d').format(startsAt.toLocal()),
    };
    return '$date · $time';
  }

  /// Price pill: e.g. "Free" or "300 ETB" from the server's display string.
  String get priceLabel => priceIsFree ? 'Free' : (priceDisplay.isEmpty ? 'Paid' : priceDisplay);

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json.strOr('id', ''),
      organizerId: json.strOr('organizer_id', ''),
      venueId: json.str('venue_id'),
      categoryId: json.str('category_id'),
      title: json.strOr('title', ''),
      description: json.strOr('description', ''),
      startsAt: json.date('starts_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: json.date('ends_at'),
      priceIsFree: json.boolOr('price_is_free', json.boolOr('is_free', true)),
      priceDisplay: json.strOr('price_display', ''),
      actionType: json.strOr('action_type', ''),
      status: json.strOr('status', ''),
      moderationStatus: json.strOr('moderation_status', ''),
      maxAttendees: json.integer('max_attendees'),
      likeCount: json.intOr('like_count', 0),
      likedByMe: json.boolOr('liked_by_me', false),
      savedByMe: json.boolOr('saved_by_me', false),
      savedFolderId: json.str('saved_folder_id'),
      posterUrl: _imageUrl(json.str('poster_url')),
      teaserUrl: _imageUrl(json.str('teaser_url')),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String? _imageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return null;
  }
}