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
  Future<dynamic> post(String path, {Object? data}) async {
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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('unauthenticated user is redirected to sign-in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const EventNuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('authenticated verified user lands on home', (tester) async {
    final storage = InMemoryTokenStorage();
    await storage.write(TokenKeys.accessToken, 'access');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const EventNuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Discover'), findsWidgets);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });
}