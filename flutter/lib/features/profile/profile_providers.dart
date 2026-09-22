import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../auth/data/user.dart';
import '../engagement/engagement_providers.dart';
import '../social/social_providers.dart';
import '../tickets/ticket_providers.dart';
import 'data/profile_badge.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

/// The signed-in user, sourced from the session's `/api/v1/users/me` fetch.
final meProvider = FutureProvider<User>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  return switch (session.value) {
    AuthStateAuthenticated(:final user) => user,
    _ => throw const ApiException(
        code: 'unauthorized',
        message: 'Sign in to see your profile.',
        statusCode: 401,
      ),
  };
});

/// Badges earned by the signed-in user.
final badgesProvider = FutureProvider<List<ProfileBadge>>(
  (ref) => ref.watch(profileRepositoryProvider).myBadges(),
);

/// Profile summary counts, derived from the already-instantiated list
/// controllers so the numbers stay in sync with Going/Saved/Tickets/Badges.
class ProfileStats {
  const ProfileStats({
    required this.going,
    required this.saved,
    required this.tickets,
    required this.badges,
  });

  final int going;
  final int saved;
  final int tickets;
  final int badges;
}

final profileStatsProvider = Provider<ProfileStats>((ref) {
  final rsvps = ref.watch(myRsvpsControllerProvider).value;
  final saves = ref.watch(mySavesControllerProvider).value;
  final tickets = ref.watch(myTicketsControllerProvider).value;
  final badges = ref.watch(badgesProvider).value;
  return ProfileStats(
    going: _count(rsvps),
    saved: _count(saves),
    tickets: tickets?.length ?? 0,
    badges: badges?.length ?? 0,
  );
});

int _count(List<dynamic>? items) => items?.length ?? 0;

/// Up to [limit] entries for a tab's summary preview.
List<dynamic> profilePreview(List<dynamic> items, {int limit = 5}) =>
    items.take(limit).toList(growable: false);