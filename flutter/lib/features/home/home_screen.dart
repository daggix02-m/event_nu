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
import '../discovery/widgets/event_feed.dart';
import 'widgets/hero_marquee.dart';
import 'widgets/stories_row.dart';
import 'widgets/floating_nav_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final categoryNames = <String, String>{};
    if (categoriesValue.value != null) {
      for (final c in categoriesValue.value!) {
        categoryNames[c.id] = c.name;
      }
    }
    final featuredCategory = featured == null ? null : categoryNames[featured.categoryId];

    final headers = <Widget>[
      HeroMarquee(featured: featured, categoryName: featuredCategory),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                user == null ? 'Discover' : 'Discover, ${user.username}',
                style: textTheme.headlineLarge,
              ),
            ),
            Expanded(child: EventFeed(headers: headers)),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(heroEventId: featured?.id),
    );
  }
}