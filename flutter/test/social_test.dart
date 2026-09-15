import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/core/api/api_client.dart';
import 'package:event_nu/core/api/api_exception.dart';
import 'package:event_nu/core/api/pagination.dart';
import 'package:event_nu/features/saves/my_saves_screen.dart';
import 'package:event_nu/features/social/data/comment.dart';
import 'package:event_nu/features/social/data/social_models.dart';
import 'package:event_nu/features/social/social_providers.dart';
import 'package:event_nu/features/social/social_repository.dart';
import 'package:event_nu/features/social/widgets/comment_section.dart';
import 'package:event_nu/features/social/widgets/social_action_row.dart';

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

class FakeSocialRepository extends SocialRepository {
  FakeSocialRepository() : super(_UnusedApiClient());

  bool throwOnLike = false;
  int likeCalls = 0;
  int saveCalls = 0;
  int followCalls = 0;
  int commentListCalls = 0;
  int createdBodies = 0;

  final comments = [
    Comment(
      id: 'c-1',
      eventId: 'e-1',
      userId: 'u-1',
      body: 'First!',
      moderationStatus: 'approved',
      createdAt: DateTime.utc(2026, 9, 1, 8),
      updatedAt: DateTime.utc(2026, 9, 1, 8),
    ),
    Comment(
      id: 'c-2',
      eventId: 'e-1',
      userId: 'u-2',
      body: 'Looking forward to this.',
      moderationStatus: 'approved',
      createdAt: DateTime.utc(2026, 9, 1, 9),
      updatedAt: DateTime.utc(2026, 9, 1, 9),
    ),
  ];

  final saves = [
    SavedEvent.fromJson(const {
      'event_id': 'e-1',
      'folder_id': 'f-1',
      'created_at': '2026-09-01T00:00:00Z',
      'event': {
        'id': 'e-1',
        'title': 'Flutter Conf 2026',
        'starts_at': '2026-10-01T09:00:00Z',
        'status': 'published',
        'is_visible': true,
      },
    }),
    SavedEvent.fromJson(const {
      'event_id': 'e-hidden',
      'created_at': '2026-09-02T00:00:00Z',
      'event': null,
    }),
  ];

  @override
  Future<LikeState> setLike(String eventId, bool liked) async {
    likeCalls++;
    if (throwOnLike) {
      throw const ApiException(code: 'server_error', message: 'Server hiccup', statusCode: 500);
    }
    return LikeState(liked: liked, likeCount: liked ? 13 : 12);
  }

  @override
  Future<SaveState> setSave(String eventId, bool saved, {String? folderId}) async {
    saveCalls++;
    return SaveState(saved: saved);
  }

  @override
  Future<FollowState> setFollow(String organizerId, bool follow) async {
    followCalls++;
    return FollowState(followerCount: 1, followedByMe: follow);
  }

  @override
  Future<Paginated<Comment>> listComments(String eventId, {int page = 1, int limit = 50}) async {
    commentListCalls++;
    return Paginated(page: 1, limit: limit, total: comments.length, hasNext: false, items: comments);
  }

  @override
  Future<Comment> createComment(String eventId, String body) async {
    createdBodies++;
    return Comment(
      id: 'c-3',
      eventId: eventId,
      userId: 'u-me',
      body: body,
      moderationStatus: 'pending',
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
    );
  }

  @override
  Future<Paginated<SavedEvent>> mySaves({int page = 1, int limit = 20}) async {
    return Paginated(page: 1, limit: limit, total: saves.length, hasNext: false, items: saves);
  }
}

Widget _wrap(Widget child, FakeSocialRepository repo) => ProviderScope(
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('model parsing', () {
    test('LikeState.fromJson reads snake_case keys', () {
      final s = LikeState.fromJson(const {'liked': true, 'like_count': 7});
      expect(s.liked, isTrue);
      expect(s.likeCount, 7);
    });

    test('SavedEvent.fromJson parses nested event summary and null event', () {
      final withEvent = SavedEvent.fromJson(const {
        'event_id': 'e-1',
        'created_at': '2026-09-01T00:00:00Z',
        'event': {'id': 'e-1', 'title': 'T', 'starts_at': '2026-10-01T09:00:00Z', 'status': 'published', 'is_visible': true},
      });
      expect(withEvent.isVisible, isTrue);
      expect(withEvent.summary?.title, 'T');

      final hidden = SavedEvent.fromJson(const {'event_id': 'e-9', 'created_at': '2026-09-01T00:00:00Z'});
      expect(hidden.isVisible, isFalse);
      expect(hidden.summary, isNull);
    });

    test('Comment.fromJson parses payload', () {
      final c = Comment.fromJson(const {
        'id': 'c-1',
        'event_id': 'e-1',
        'user_id': 'u-1',
        'body': 'hi',
        'moderation_status': 'approved',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      });
      expect(c.id, 'c-1');
      expect(c.body, 'hi');
      expect(c.moderationStatus, 'approved');
    });
  });

  group('SocialActionRow', () {
    testWidgets('optimistically toggles like and keeps server count', (tester) async {
      final repo = FakeSocialRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [socialRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(
            body: SocialActionRow(eventId: 'e-1', initialLiked: false, initialLikeCount: 0, initialSaved: false),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(repo.likeCalls, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
    });

    testWidgets('rolls back optimistic like on failure', (tester) async {
      final repo = FakeSocialRepository()..throwOnLike = true;
      await tester.pumpWidget(ProviderScope(
        overrides: [socialRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(
            body: SocialActionRow(eventId: 'e-1', initialLiked: true, initialLikeCount: 12, initialSaved: false),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(repo.likeCalls, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Server hiccup'), findsOneWidget);
    });
  });

  group('CommentSection', () {
    testWidgets('renders comments and posts a new one', (tester) async {
      final repo = FakeSocialRepository();
      await tester.pumpWidget(_wrap(const CommentSection(eventId: 'e-1'), repo));
      await tester.pumpAndSettle();

      expect(find.text('First!'), findsOneWidget);
      expect(find.text('Looking forward to this.'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Count me in!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(repo.createdBodies, 1);
      expect(find.text('Count me in!'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('MySavesScreen', () {
    testWidgets('groups saves by folder and removes on unsave', (tester) async {
      final repo = FakeSocialRepository();
      await tester.pumpWidget(_wrap(const MySavesScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Conf 2026'), findsOneWidget);
      expect(find.text('Unavailable event'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_remove_outlined), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.bookmark_remove_outlined).first);
      await tester.pumpAndSettle();

      expect(repo.saveCalls, 1);
      expect(find.text('Flutter Conf 2026'), findsNothing);
      expect(find.text('Unavailable event'), findsOneWidget);
    });
  });
}