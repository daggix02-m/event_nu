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
import 'package:event_nu/features/auth/data/user.dart';
import 'package:event_nu/features/organizer/data/organizer_application.dart';
import 'package:event_nu/features/organizer/organizer_providers.dart';
import 'package:event_nu/features/organizer/organizer_repository.dart';

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

  @override
  Future<User> fetchMe() async => _user;

  static final User _user = User(
    id: 'user-1',
    email: 'dev@eventnu.test',
    username: 'dev',
    role: 'user',
    isVerified: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class FakeOrganizerRepo extends OrganizerRepository {
  FakeOrganizerRepo() : super(_UnusedApiClient());

  ApiException? applyError;
  OrganizerApplication? existing;
  late String appliedName;

  @override
  Future<OrganizerApplication> getMyApplication() async {
    final app = existing;
    if (app == null) {
      throw const ApiException(
        code: 'not_found',
        message: 'No application found.',
        statusCode: 404,
      );
    }
    return app;
  }

  @override
  Future<OrganizerApplication> apply({
    required String requestedName,
    required String requestedSlug,
    required String bio,
  }) async {
    final error = applyError;
    if (error != null) throw error;
    appliedName = requestedName;
    return OrganizerApplication(
      id: 'app-1',
      requestedName: requestedName,
      requestedSlug: requestedSlug.isNotEmpty ? requestedSlug : 'admas-coffee',
      bio: bio,
      status: 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

Widget _app(FakeAuthRepo auth, FakeOrganizerRepo organizer) {
  final storage = InMemoryTokenStorage();
  storage.write(TokenKeys.accessToken, 'access');
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(auth),
      organizerRepositoryProvider.overrideWithValue(organizer),
    ],
    child: const EventNuApp(),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openOrganize(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Host in Addis'));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('organizer wizard applies with only backend fields', (tester) async {
    final organizer = FakeOrganizerRepo();
    await tester.pumpWidget(_app(FakeAuthRepo(), organizer));
    await tester.pumpAndSettle();

    await _openOrganize(tester);

    expect(find.text('Host in Addis'), findsOneWidget);
    expect(find.text('Organization name'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Organization name'), 'Admas Coffee');
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));

    // Review step shows the slug preview derived from the name.
    expect(find.textContaining('eventnu.et/@admas-coffee'), findsOneWidget);

    await _tapVisible(tester, find.text('Apply to host'));

    expect(find.text('Application in review'), findsOneWidget);
    expect(organizer.appliedName, 'Admas Coffee');
    expect(find.text('Admas Coffee'), findsNothing); // status screen shown
  });

  testWidgets('an existing pending application opens the status screen',
      (tester) async {
    final organizer = FakeOrganizerRepo()
      ..existing = OrganizerApplication(
        id: 'app-0',
        requestedName: 'Old Hub',
        requestedSlug: 'old-hub',
        bio: '',
        status: 'pending',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    await tester.pumpWidget(_app(FakeAuthRepo(), organizer));
    await tester.pumpAndSettle();

    await _openOrganize(tester);

    expect(find.text('Application in review'), findsOneWidget);
    expect(find.text('Organization name'), findsNothing);
  });

  testWidgets('a prior application_pending 409 stays honest on the review step',
      (tester) async {
    final organizer = FakeOrganizerRepo()
      ..applyError = const ApiException(
        code: 'application_pending',
        message: 'You already have a pending organizer application.',
        statusCode: 409,
      );
    await tester.pumpWidget(_app(FakeAuthRepo(), organizer));
    await tester.pumpAndSettle();

    await _openOrganize(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Organization name'), 'Admas Coffee');
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _tapVisible(tester, find.text('Apply to host'));

    expect(find.text('Application in review'), findsNothing);
    expect(find.text('You already have a pending organizer application.'),
        findsOneWidget);
  });
}