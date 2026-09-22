import 'package:flutter/material.dart';

import '../../../core/ext/json_utils.dart';

/// An achievement a user has earned, mirroring the backend's badge DTO.
class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.badgeType,
    required this.earnedAt,
    this.metadata = const {},
  });

  final String id;
  final String badgeType;
  final DateTime earnedAt;
  final Map<String, dynamic> metadata;

  factory ProfileBadge.fromJson(Map<String, dynamic> json) {
    return ProfileBadge(
      id: json.strOr('id', ''),
      badgeType: json.strOr('badge_type', ''),
      earnedAt: json.date('earned_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      metadata: json.object('metadata') ?? const {},
    );
  }

  String get label => switch (badgeType) {
        'first_rsvp' => 'First RSVP',
        'first_attended' => 'First Event',
        'first_ticket' => 'First Ticket',
        'first_moment' => 'First Moment',
        _ => badgeType,
      };

  String get description => switch (badgeType) {
        'first_rsvp' => 'Committed to your first event',
        'first_attended' => 'Attended your first event',
        'first_ticket' => 'Bought your first ticket',
        'first_moment' => 'Shared your first moment',
        _ => 'Earned badge',
      };

  IconData get icon => switch (badgeType) {
        'first_rsvp' => Icons.event_available,
        'first_attended' => Icons.celebration,
        'first_ticket' => Icons.confirmation_number,
        'first_moment' => Icons.photo_camera,
        _ => Icons.emoji_events,
      };
}