import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:event_nu/app/app.dart';
import 'package:event_nu/app/providers.dart';
import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/api_exception.dart';
import 'package:event_nu/core/storage/token_storage.dart';
import 'package:event_nu/features/auth/auth_repository.dart';
import 'package:event_nu/features/auth/data/auth_tokens.dart';
import 'package:event_nu/features/auth/data/user.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) =>
      throw UnimplementedError();
}

class FakeAuthRepo extends AuthRepository {
  FakeAuthRepo() : super(_UnusedApiClient());

  User user = User(
    id: 'user-1',
    email: 'dev@eventnu.test',
    username: 'dev',
    role: 'user',
    isVerified: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  ApiException? loginError;
  ApiException? registerError;

  @override
  Future<User> fetchMe() async => user;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final error = loginError;
    if (error != null) throw error;
    return AuthResponse(user: user.copyWith(email: email), tokens: _tokens());
  }

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    return AuthResponse(
      user: user.copyWith(email: email, username: username),
      tokens: _tokens(),
    );
  }

  AuthTokens _tokens() => const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresInSeconds: 3600,
      );
}

Widget _app(FakeAuthRepo auth) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authRepositoryProvider.overrideWithValue(auth),
    ],
    child: const EventNuApp(),
  );
}

Future<void> _goToSignIn(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('register wizard collects only backend fields across two steps',
      (tester) async {
    final auth = FakeAuthRepo();
    auth.user = auth.user.copyWith(isVerified: false);
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _goToSignIn(tester);
    await _tapVisible(tester, find.text('New to Event Nu? Create an account'));

    expect(find.text('Join the Addis Radar'), findsOneWidget);
    final continueBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueBtn.onPressed, isNull); // nothing filled yet

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'dev@eventnu.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Handle'), 'daggi');
    await tester.pump();

    final enabledContinue = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(enabledContinue.onPressed, isNotNull);

    await _tapVisible(tester, find.text('Continue'));

    // Step two: password + confirm only.
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Handle'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secure-pass');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'secure-pass');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Create account'));

    // Unverified user is sent to verify, and the resend control is honest.
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Resend code'), findsNothing);
    expect(find.textContaining('No code yet?'), findsOneWidget);
  });

  testWidgets('register wizard stays on the password step when passwords differ',
      (tester) async {
    final auth = FakeAuthRepo();
    auth.user = auth.user.copyWith(isVerified: false);
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _goToSignIn(tester);
    await _tapVisible(tester, find.text('New to Event Nu? Create an account'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'dev@eventnu.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Handle'), 'daggi');
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Continue'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secure-pass');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'different-pass');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Create account'));

    expect(find.text('Check your inbox'), findsNothing);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('sign-in surfaces mapped server errors under the form',
      (tester) async {
    final auth = FakeAuthRepo()
      ..loginError = const ApiException(
        code: 'invalid_credentials',
        message: 'Invalid email or password.',
        statusCode: 401,
      );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _goToSignIn(tester);
    expect(find.text('Get your pass to Addis.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'dev@eventnu.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
}