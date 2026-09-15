import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/features/engagement/data/engagement_models.dart';
import 'package:event_nu/features/engagement/engagement_providers.dart';
import 'package:event_nu/features/engagement/engagement_repository.dart';
import 'package:event_nu/features/engagement/my_rsvps_screen.dart';
import 'package:event_nu/features/engagement/notifications_screen.dart';
import 'package:event_nu/features/engagement/widgets/report_sheet.dart';
import 'package:event_nu/features/engagement/widgets/rsvp_button.dart';

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(dio: Dio());
  @override
  Future<dynamic> delete(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getEnvelope(String path, {Map<String, dynamic>? queryParameters}) async => throw UnimplementedError();
  @override
  Future<dynamic> patch(String path, {Object? data}) async => throw UnimplementedError();
  @override
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) async => throw UnimplementedError();
}

class FakeEngagementRepository extends EngagementRepository {
  FakeEngagementRepository() : super(_UnusedApiClient());

  bool going = false;
  int setRsvpCalls = 0;
  int cancelRsvpCalls = 0;
  int reportCalls = 0;

  final reviews = [
    ReviewItem(
      id: 'r-1',
      eventId: 'e-1',
      userId: 'u-1',
      rating: 5,
      body: 'Fantastic',
      status: 'approved',
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ),
  ];

  final notifications = [
    NotificationItem(
      id: 'n-1',
      type: 'like',
      title: 'Someone liked your event',
      body: '',
      createdAt: DateTime.utc(2026, 9, 5, 8),
    ),
    NotificationItem(
      id: 'n-2',
      type: 'system',
      title: 'Welcome!',
      body: 'Explore upcoming events.',
      readAt: DateTime.utc(2026, 9, 4),
      createdAt: DateTime.utc(2026, 9, 4),
    ),
  ];

  final rsvps = [
    MyRsvp.fromJson(const {
      'event_id': 'e-1',
      'status': 'going',
      'public_rsvp': true,
      'created_at': '2026-09-01T00:00:00Z',
      'event': {
        'id': 'e-1',
        'title': 'Flutter Conf 2026',
        'starts_at': '2026-10-01T09:00:00Z',
        'status': 'published',
        'is_visible': true,
      },
    }),
  ];

  @override
  Future<RsvpState> rsvpState(String eventId) async => RsvpState(going: going);

  @override
  Future<RsvpState> setRsvp(String eventId, {bool? publicRsvp}) async {
    setRsvpCalls++;
    going = true;
    return RsvpState(going: true);
  }

  @override
  Future<RsvpState> cancelRsvp(String eventId) async {
    cancelRsvpCalls++;
    going = false;
    return RsvpState(going: false);
  }

  @override
  Future<Paginated<MyRsvp>> myRsvps({int page = 1, int limit = 20}) async {
    return Paginated(page: 1, limit: limit, total: rsvps.length, hasNext: false, items: rsvps);
  }

  @override
  Future<Paginated<NotificationItem>> listNotifications({int page = 1, int limit = 30}) async {
    return Paginated(page: 1, limit: limit, total: notifications.length, hasNext: false, items: notifications);
  }

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<Paginated<ReviewItem>> listReviews(String eventId, {int page = 1, int limit = 20}) async {
    return Paginated(page: 1, limit: limit, total: reviews.length, hasNext: false, items: reviews);
  }

  @override
  Future<ReportResult> report(String entityType, String entityId, {required String reasonCode, String description = ''}) async {
    reportCalls++;
    return const ReportResult(reported: true);
  }
}

Widget _wrap(Widget child, FakeEngagementRepository repo) => ProviderScope(
      overrides: [
        engagementRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('model parsing', () {
    test('RsvpState.fromJson reads going', () {
      final s = RsvpState.fromJson(const {'going': true, 'status': 'going'});
      expect(s.going, isTrue);
      expect(s.status, 'going');
    });

    test('MyRsvp.fromJson parses nested event summary', () {
      final rs = MyRsvp.fromJson(const {
        'event_id': 'e-1',
        'status': 'going',
        'public_rsvp': true,
        'event': {'id': 'e-1', 'title': 'T', 'starts_at': '2026-10-01T09:00:00Z', 'status': 'published', 'is_visible': true},
      });
      expect(rs.isVisible, isTrue);
      expect(rs.summary?.title, 'T');
    });

    test('NotificationItem.isRead is true only when read_at present', () {
      final read = NotificationItem.fromJson(const {
        'id': 'n',
        'type': 'like',
        'title': 't',
        'body': '',
        'data': {},
        'read_at': '2026-09-05T00:00:00Z',
        'created_at': '2026-09-04T00:00:00Z',
      });
      expect(read.isRead, isTrue);
      final unread = NotificationItem.fromJson(const {
        'id': 'n2',
        'type': 'like',
        'title': 't',
        'body': '',
        'data': {},
        'created_at': '2026-09-04T00:00:00Z',
      });
      expect(unread.isRead, isFalse);
    });

    test('ReviewItem.fromJson parses rating and body', () {
      final r = ReviewItem.fromJson(const {
        'id': 'r-1',
        'event_id': 'e-1',
        'user_id': 'u-1',
        'rating': 4,
        'body': 'Good',
        'status': 'approved',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      });
      expect(r.rating, 4);
      expect(r.body, 'Good');
    });
  });

  group('RsvpButton', () {
    testWidgets('toggles from going to not going', (tester) async {
      final repo = FakeEngagementRepository();
      await tester.pumpWidget(_wrap(const RsvpButton(eventId: 'e-1'), repo));
      await tester.pumpAndSettle();
      expect(find.text("I'm going"), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.setRsvpCalls, 1);
      expect(find.text('You are going'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.cancelRsvpCalls, 1);
      expect(find.text("I'm going"), findsOneWidget);
    });
  });

  group('report sheet', () {
    testWidgets('submits a report with the chosen reason', (tester) async {
      final repo = FakeEngagementRepository();
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showReportSheet(context, entityType: 'event', entityId: 'e-1'),
              child: const Text('open'),
            ),
          ),
        ),
        repo,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Spam or scam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(repo.reportCalls, 1);
      expect(find.text('Thanks — our team will review this.'), findsOneWidget);
    });
  });

  group('NotificationsScreen', () {
    testWidgets('renders inbox and marks an unread item read on tap', (tester) async {
      final repo = FakeEngagementRepository();
      await tester.pumpWidget(_wrap(const NotificationsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Someone liked your event'), findsOneWidget);
      expect(find.text('Welcome!'), findsOneWidget);

      await tester.tap(find.text('Someone liked your event'));
      await tester.pumpAndSettle();

      expect(find.text('Someone liked your event'), findsOneWidget);
    });
  });

  group('MyRsvpsScreen', () {
    testWidgets('renders going events and allows cancelling', (tester) async {
      final repo = FakeEngagementRepository()..going = true;
      await tester.pumpWidget(_wrap(const MyRsvpsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Conf 2026'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.event_busy));
      await tester.pumpAndSettle();

      expect(repo.cancelRsvpCalls, 1);
      expect(find.text('Flutter Conf 2026'), findsNothing);
    });
  });
}