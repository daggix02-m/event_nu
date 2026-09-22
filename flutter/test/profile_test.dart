import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:event_nu/app/app.dart';
import 'package:event_nu/app/providers.dart';
import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/core/storage/token_storage.dart';
import 'package:event_nu/features/auth/auth_repository.dart';
import 'package:event_nu/features/auth/data/user.dart';
import 'package:event_nu/features/discovery/data/category.dart';
import 'package:event_nu/features/discovery/data/event.dart';
import 'package:event_nu/features/discovery/discovery_providers.dart';
import 'package:event_nu/features/discovery/discovery_repository.dart';
import 'package:event_nu/features/engagement/data/engagement_models.dart';
import 'package:event_nu/features/engagement/engagement_providers.dart';
import 'package:event_nu/features/engagement/engagement_repository.dart';
import 'package:event_nu/features/profile/data/profile_badge.dart';
import 'package:event_nu/features/profile/profile_providers.dart';
import 'package:event_nu/features/profile/profile_repository.dart';
import 'package:event_nu/features/social/data/social_models.dart';
import 'package:event_nu/features/social/social_providers.dart';
import 'package:event_nu/features/social/social_repository.dart';
import 'package:event_nu/features/tickets/data/ticket_models.dart';
import 'package:event_nu/features/tickets/ticket_providers.dart';
import 'package:event_nu/features/tickets/ticket_repository.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async =>
      throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) async =>
      throw UnimplementedError();
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(_UnusedApiClient());
  @override
  Future<User> fetchMe() async => User(
        id: 'user-1',
        email: 'dev@eventnu.test',
        username: 'dev',
        bio: 'Building things in Addis.',
        role: 'user',
        isVerified: true,
        createdAt: DateTime(2025, 5, 1),
      );
  @override
  Future<void> logout({required String refreshToken, required String accessToken}) async {}
}

class FakeDiscoveryRepository extends DiscoveryRepository {
  FakeDiscoveryRepository() : super(_UnusedApiClient());
  @override
  Future<List<Category>> listCategories() async => const [];
  @override
  Future<Paginated<Event>> listEvents({
    String? query,
    String? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    return Paginated(
      page: 1,
      limit: limit,
      total: 0,
      hasNext: false,
      items: const [],
    );
  }
}

class FakeEngagementRepository extends EngagementRepository {
  FakeEngagementRepository() : super(_UnusedApiClient());
  @override
  Future<Paginated<MyRsvp>> myRsvps({int page = 1, int limit = 20}) async {
    return Paginated(
      page: page,
      limit: limit,
      total: 1,
      hasNext: false,
      items: [
        MyRsvp(
          eventId: 'e-going',
          status: 'confirmed',
          summary: EventSummary(
            id: 'e-going',
            title: 'Going Event',
            startsAt: DateTime(2026, 10, 1, 9),
            status: 'published',
            isVisible: true,
          ),
        ),
      ],
    );
  }
}

class FakeSocialRepository extends SocialRepository {
  FakeSocialRepository() : super(_UnusedApiClient());
  @override
  Future<Paginated<SavedEvent>> mySaves({int page = 1, int limit = 20}) async {
    return Paginated(
      page: page,
      limit: limit,
      total: 1,
      hasNext: false,
      items: [
        SavedEvent(
          eventId: 'e-save',
          createdAt: DateTime(2026, 9, 1),
          summary: EventSummary(
            id: 'e-save',
            title: 'Saved Event',
            startsAt: DateTime(2026, 11, 5, 18),
            status: 'published',
            isVisible: true,
          ),
        ),
      ],
    );
  }
}

class FakeTicketRepository extends TicketRepository {
  FakeTicketRepository() : super(_UnusedApiClient());
  @override
  Future<List<TicketItem>> myTickets() async {
    return [
      TicketItem(
        id: 'ticket-1',
        orderItemId: 'oi-1',
        eventId: 'e-ticket',
        ticketTypeId: 'tt-1',
        status: 'valid',
        issuedAt: DateTime(2026, 9, 10),
        qr: const TicketQr(
          ticketId: 'ticket-1',
          eventId: 'e-ticket',
          issuedAt: '2026-09-10T00:00:00Z',
          hmac: 'hmac',
        ),
      ),
    ];
  }
}

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(_UnusedApiClient());
  @override
  Future<List<ProfileBadge>> myBadges() async {
    return [
      ProfileBadge(
        id: 'b-rsvp',
        badgeType: 'first_rsvp',
        earnedAt: DateTime(2026, 8, 15),
      ),
      ProfileBadge(
        id: 'b-ticket',
        badgeType: 'first_ticket',
        earnedAt: DateTime(2026, 9, 10),
      ),
    ];
  }
}

Future<Widget> _app() async {
  final storage = InMemoryTokenStorage();
  await storage.write(TokenKeys.accessToken, 'access');
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
      engagementRepositoryProvider.overrideWithValue(FakeEngagementRepository()),
      socialRepositoryProvider.overrideWithValue(FakeSocialRepository()),
      ticketRepositoryProvider.overrideWithValue(FakeTicketRepository()),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    ],
    child: const EventNuApp(),
  );
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.pumpWidget(await _app());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.person_outline));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('profile shows the identity card with stats and going preview',
      (tester) async {
    await _openProfile(tester);

    expect(find.text('Your profile'), findsOneWidget);

    expect(find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Your profile'),
    ), findsOneWidget);

    expect(find.text('dev'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Building things in Addis.'), findsOneWidget);
    expect(find.textContaining('Member since May 2025'), findsOneWidget);

    expect(find.text('Going Event'), findsOneWidget);

    final going = find.descendant(
      of: find.byKey(const ValueKey('stat-going')),
      matching: find.text('1'),
    );
    final saved = find.descendant(
      of: find.byKey(const ValueKey('stat-saved')),
      matching: find.text('1'),
    );
    final tickets = find.descendant(
      of: find.byKey(const ValueKey('stat-tickets')),
      matching: find.text('1'),
    );
    final badges = find.descendant(
      of: find.byKey(const ValueKey('stat-badges')),
      matching: find.text('2'),
    );
    expect(going, findsOneWidget);
    expect(saved, findsOneWidget);
    expect(tickets, findsOneWidget);
    expect(badges, findsOneWidget);
  });

  testWidgets('badges tab renders the earned badge grid', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('tab-badges')));
    await tester.pumpAndSettle();

    expect(find.text('First RSVP'), findsOneWidget);
    expect(find.text('First Ticket'), findsOneWidget);
    expect(find.text('Earned August 2026'), findsOneWidget);
    expect(find.text('Earned September 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.event_available),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.confirmation_number),
      ),
      findsOneWidget,
    );
  });

  testWidgets('going stat opens the full RSVP list', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('stat-going')));
    await tester.pumpAndSettle();

    expect(find.text("Events I'm going to"), findsOneWidget);
  });

  testWidgets('saved stat opens the full saves list', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('stat-saved')));
    await tester.pumpAndSettle();

    expect(find.text('My Saves'), findsOneWidget);
  });

  testWidgets('tickets stat opens the full tickets list', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('stat-tickets')));
    await tester.pumpAndSettle();

    expect(find.text('My Tickets'), findsOneWidget);
  });

  testWidgets('saved tab preview lists the saved event', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('tab-saved')));
    await tester.pumpAndSettle();

    expect(find.text('Saved Event'), findsOneWidget);
    expect(find.byKey(const ValueKey('see-all-saved')), findsOneWidget);
  });

  testWidgets('tickets tab preview lists the issued ticket', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byKey(const ValueKey('tab-tickets')));
    await tester.pumpAndSettle();

    expect(find.text('Valid ticket'), findsOneWidget);
    expect(find.text('Issued Sep 10'), findsOneWidget);
  });
}