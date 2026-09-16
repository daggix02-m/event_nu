import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:event_nu/app/app.dart';
import 'package:event_nu/app/providers.dart';
import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/storage/token_storage.dart';
import 'package:event_nu/features/auth/auth_repository.dart';
import 'package:event_nu/features/auth/data/user.dart';
import 'package:event_nu/features/splash/splash_screen.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());

  @override
  Future<dynamic> delete(String path, {Object? data}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> patch(String path, {Object? data}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) async {
    throw UnimplementedError();
  }
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(_UnusedApiClient());

  User user = User(
    id: 'user-1',
    email: 'dev@eventnu.test',
    username: 'dev',
    role: 'user',
    isVerified: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<User> Function()? onFetchMe;

  @override
  Future<User> fetchMe() async {
    final override = onFetchMe;
    if (override != null) return override();
    return user;
  }

  @override
  Future<void> logout({
    required String refreshToken,
    required String accessToken,
  }) async {}
}

_Widget _app({InMemoryTokenStorage? storage, FakeAuthRepository? auth}) {
  return _Widget(storage: storage, auth: auth);
}

class _Widget extends StatelessWidget {
  const _Widget({this.storage, this.auth});

  final InMemoryTokenStorage? storage;
  final FakeAuthRepository? auth;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage ?? InMemoryTokenStorage()),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ],
      child: const EventNuApp(),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the branded splash during bootstrap', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('unauthenticated user lands on home (home-first)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Discover'), findsWidgets);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('unauthenticated user is sent to sign-in on a protected route', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('unverified user is redirected to the verify screen', (tester) async {
    final auth = FakeAuthRepository();
    auth.user = auth.user.copyWith(isVerified: false);
    final storage = InMemoryTokenStorage();
    await storage.write(TokenKeys.accessToken, 'access');

    await tester.pumpWidget(_app(storage: storage, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
  });

  testWidgets('authenticated verified user lands on home', (tester) async {
    final storage = InMemoryTokenStorage();
    await storage.write(TokenKeys.accessToken, 'access');

    await tester.pumpWidget(_app(storage: storage));
    await tester.pumpAndSettle();

    expect(find.textContaining('Discover'), findsWidgets);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });
}