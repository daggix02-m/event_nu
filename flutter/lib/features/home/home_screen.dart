import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/auth/session.dart';
import '../../design/app_colors.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/host_banner.dart';
import '../../shared/widgets/event_nu_logo.dart';
import '../discovery/data/event.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/widgets/category_pills.dart';
import '../discovery/widgets/category_shelf_section.dart';
import '../discovery/widgets/event_feed.dart';
import '../discovery/widgets/featured_carousel.dart';
import '../schedule/schedule_view.dart';
import 'widgets/stories_row.dart';
import 'widgets/floating_nav_bar.dart';

enum HomeView { discover, schedule }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeView _view = HomeView.discover;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider).value;
    final user = switch (session) {
      AuthStateAuthenticated(:final user) => user,
      _ => null,
    };
    final categoriesValue = ref.watch(categoriesProvider);
    final feed = ref.watch(feedControllerProvider);
    final events = feed.value ?? const <Event>[];
    final selectedCategory = ref.read(feedControllerProvider.notifier).categoryId;

    final photos = [
      for (final e in events)
        if (e.posterUrl != null || e.teaserUrl != null) e,
    ];
    final featured = photos.isNotEmpty ? photos.first : (events.isNotEmpty ? events.first : null);
    final headers = <Widget>[
      FeaturedCarousel(events: events),
      StoriesRow(events: events),
      if (user != null && !user.isVerified)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Card(
            color: AppColors.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.mark_email_unread, color: AppColors.onSecondaryContainer),
              title: const Text('Email not verified yet'),
              subtitle: const Text('Some actions remain unavailable until you verify.'),
              trailing: FilledButton(
                onPressed: () => context.go(AppRoute.verify.path),
                child: const Text('Verify'),
              ),
            ),
          ),
        ),
      if (user != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: HostBanner(onTap: () => context.go(AppRoute.organize.path)),
        ),
      categoriesValue.when(
        loading: () => const SizedBox(height: 40),
        error: (_, _) => const SizedBox(height: 40),
        data: (categories) => SizedBox(
          width: double.infinity,
          child: CategoryPills(
            categories: categories,
            selectedId: selectedCategory,
            onSelected: (id) => ref.read(feedControllerProvider.notifier).setCategory(id),
          ),
        ),
      ),
      const CategoryShelfSection(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: EventNuLogo.mark(width: 34),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.go(AppRoute.search.path),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () => context.go(AppRoute.notifications.path),
          ),
          IconButton(
            icon: const Icon(Icons.event_available_outlined),
            tooltip: "Events I'm going to",
            onPressed: () => context.go(AppRoute.myRsvps.path),
          ),
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'My Tickets',
            onPressed: () => context.go(AppRoute.myTickets.path),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'My Saves',
            onPressed: () => context.go(AppRoute.saves.path),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                user == null ? 'Discover' : 'Discover, ${user.username}',
                style: textTheme.headlineLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<HomeView>(
                segments: const [
                  ButtonSegment(
                    value: HomeView.discover,
                    label: Text('Discover'),
                    icon: Icon(Icons.explore_outlined),
                  ),
                  ButtonSegment(
                    value: HomeView.schedule,
                    label: Text('Schedule'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _view == HomeView.discover
                    ? EventFeed(
                        key: const ValueKey('home-discover'),
                        headers: headers,
                      )
                    : const ScheduleView(key: ValueKey('home-schedule')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(heroEventId: featured?.id),
    );
  }
}