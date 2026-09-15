import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/auth/screens/verify_screen.dart';
import '../features/home/home_screen.dart';

enum AppRoute {
  home('/'),
  signIn('/auth/sign-in'),
  register('/auth/register'),
  verify('/auth/verify');

  const AppRoute(this.path);

  final String path;
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
    initialLocation: AppRoute.signIn.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final authState = session.value;
      final loggingIn = state.matchedLocation == AppRoute.signIn.path ||
          state.matchedLocation == AppRoute.register.path;

      if (session.isLoading && !session.hasValue) return null;
      if (authState == null || authState is AuthStateUnknown) return null;

      final isUnauthenticated = authState is AuthStateUnauthenticated;
      final isVerified = switch (authState) {
        AuthStateAuthenticated(:final user) => user.isVerified,
        _ => false,
      };

      if (isUnauthenticated) {
        return loggingIn ? null : AppRoute.signIn.path;
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
    ],
  );
});