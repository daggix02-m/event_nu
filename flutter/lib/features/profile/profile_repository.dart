import '../../core/api/api_client.dart';
import 'data/profile_badge.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// The user's earned badges. `/api/v1/users/me/badges` responds with a
  /// bare array (not an envelope), so fetch via [ApiClient.get].
  Future<List<ProfileBadge>> myBadges() async {
    final data = await _api.get('/api/v1/users/me/badges');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ProfileBadge.fromJson)
        .toList(growable: false);
  }
}