import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/features/discovery/data/event.dart';
import 'package:event_nu/features/discovery/widgets/featured_carousel.dart';

Event _event(String id, int day) => Event.fromJson({
      'id': id,
      'organizer_id': 'org-1',
      'category_id': 'c1',
      'title': 'Event $id',
      'description': 'desc',
      'poster_url': 'https://img.test/poster-$id.jpg',
      'starts_at': '2026-10-0${day}T09:00:00Z',
      'price_is_free': true,
      'price_display': '',
      'action_type': '',
      'status': 'published',
      'moderation_status': 'approved',
      'like_count': 0,
      'liked_by_me': false,
      'saved_by_me': false,
      'created_at': '2026-09-01T00:00:00Z',
    });

Future<void> _pump(WidgetTester tester, List<Event> events) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 360,
          child: FeaturedCarousel(events: events),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('falls back to HeroMarquee when fewer than two events have media',
      (tester) async {
    await _pump(tester, [_event('e-1', 1)]);

    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
    expect(find.text('Event e-1'), findsOneWidget);

    // No periodic auto-advance timer when in fallback mode, so no unmount
    // needed; still teardown cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('left and right tap zones step between featured events',
      (tester) async {
    final events = [_event('e-1', 1), _event('e-2', 2)];
    await _pump(tester, events);

    await tester.pump();
    // Each slide renders its title twice: the headline and the category chip.
    expect(find.text('Event e-1'), findsNWidgets(2));
    expect(find.text('Event e-2'), findsNothing);

    // Right third → next slide.
    await tester.tapAt(const Offset(700, 180));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Event e-2'), findsNWidgets(2));
    expect(find.text('Event e-1'), findsNothing);

    // Left third wraps back to the first slide.
    await tester.tapAt(const Offset(100, 180));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Event e-1'), findsNWidgets(2));
    expect(find.text('Event e-2'), findsNothing);

    // Middle third (where the slide content sits) is inert.
    await tester.tapAt(const Offset(400, 180));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Event e-1'), findsNWidgets(2));
    expect(find.text('Event e-2'), findsNothing);

    // Unmount to cancel the periodic auto-advance timer.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('auto-advances to the next slide after the advance interval',
      (tester) async {
    final events = [_event('e-1', 1), _event('e-2', 2)];
    await _pump(tester, events);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Event e-2'), findsNWidgets(2));
    expect(find.text('Event e-1'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}