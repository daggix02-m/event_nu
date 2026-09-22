import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/auth/screens/verify_screen.dart';
import '../features/engagement/my_rsvps_screen.dart';
import '../features/engagement/notifications_screen.dart';
import '../features/event_details/event_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/city_map_screen.dart';
import '../features/moments/event_gallery_screen.dart';
import '../features/organizer/organizer_application_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/saves/my_saves_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/search/search_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tickets/my_tickets_screen.dart';
import '../features/venues/venue_detail_screen.dart';

enum AppRoute {
  home('/'),
  splash('/splash'),
  signIn('/auth/sign-in'),
  register('/auth/register'),
  verify('/auth/verify'),
  search('/search'),
  saves('/saves'),
  schedule('/schedule'),
  myTickets('/my-tickets'),
  notifications('/notifications'),
  myRsvps('/my-rsvps'),
  organize('/organize'),
  map('/map'),
  profile('/profile');

  const AppRoute(this.path);

  final String path;

  static String event(String id) => '/events/$id';
  static String venue(String id) => '/venues/$id';
}

class _SessionRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(sessionControllerProvider, (_, _) {
    refresh.notify();
  });

  return GoRouter(
    initialLocation: AppRoute.home.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final authState = session.value;
      final loggingIn = state.matchedLocation == AppRoute.signIn.path ||
          state.matchedLocation == AppRoute.register.path;

      // Show the branded splash until the initial session restore finishes.
      if (!ref.read(sessionControllerProvider.notifier).bootstrapped) {
        return AppRoute.splash.path;
      }
      // Splash is only for launch; once restored, route by session state.
      if (state.matchedLocation == AppRoute.splash.path) {
        return AppRoute.home.path;
      }

      if (session.isLoading && !session.hasValue) return null;
      if (authState == null || authState is AuthStateUnknown) return null;

      final isUnauthenticated = authState is AuthStateUnauthenticated;
      final isVerified = switch (authState) {
        AuthStateAuthenticated(:final user) => user.isVerified,
        _ => false,
      };

      if (isUnauthenticated) {
        final publicRoute = loggingIn ||
            state.matchedLocation == AppRoute.home.path ||
            state.matchedLocation == AppRoute.search.path ||
            state.matchedLocation == AppRoute.map.path ||
            state.matchedLocation == AppRoute.profile.path ||
            state.matchedLocation.startsWith('/events/') ||
            state.matchedLocation.startsWith('/venues/');
        return publicRoute ? null : AppRoute.signIn.path;
      }

      if (!isVerified) {
        final atVerify = state.matchedLocation == AppRoute.verify.path;
        return atVerify ? null : AppRoute.verify.path;
      }

      if (loggingIn) return AppRoute.home.path;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.signIn.path,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoute.register.path,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoute.verify.path,
        builder: (_, _) => const VerifyScreen(),
      ),
      GoRoute(
        path: AppRoute.search.path,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoute.saves.path,
        builder: (_, _) => const MySavesScreen(),
      ),
      GoRoute(
        path: AppRoute.schedule.path,
        builder: (_, _) => const ScheduleScreen(),
      ),
      GoRoute(
        path: AppRoute.myTickets.path,
        builder: (_, _) => const MyTicketsScreen(),
      ),
      GoRoute(
        path: AppRoute.notifications.path,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.myRsvps.path,
        builder: (_, _) => const MyRsvpsScreen(),
      ),
      GoRoute(
        path: AppRoute.organize.path,
        builder: (_, _) => const OrganizerApplicationScreen(),
      ),
      GoRoute(
        path: AppRoute.map.path,
        builder: (_, _) => const CityMapScreen(),
      ),
      GoRoute(
        path: AppRoute.profile.path,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'gallery',
            builder: (_, state) =>
                EventGalleryScreen(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/venues/:id',
        builder: (_, state) => VenueDetailScreen(venueId: state.pathParameters['id']!),
      ),
    ],
  );
});