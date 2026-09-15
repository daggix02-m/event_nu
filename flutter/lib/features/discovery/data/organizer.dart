import '../../../core/ext/json_utils.dart';

class Organizer {
  const Organizer({
    required this.id,
    required this.slug,
    required this.name,
    required this.bio,
    required this.status,
    required this.followerCount,
    required this.followedByMe,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String bio;
  final String status;
  final int followerCount;
  final bool followedByMe;
  final DateTime createdAt;

  factory Organizer.fromJson(Map<String, dynamic> json) {
    return Organizer(
      id: json.strOr('id', ''),
      slug: json.strOr('slug', ''),
      name: json.strOr('name', ''),
      bio: json.strOr('bio', ''),
      status: json.strOr('status', ''),
      followerCount: json.intOr('follower_count', 0),
      followedByMe: json.boolOr('followed_by_me', false),
      createdAt: json.date('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}