import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../core/auth/session.dart';
import '../../design/app_colors.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/widgets/category_pills.dart';
import '../discovery/widgets/event_feed.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = switch (session) {
      AuthStateAuthenticated(:final user) => user,
      _ => null,
    };
    final categoriesValue = ref.watch(categoriesProvider);
    ref.watch(feedControllerProvider);
    final selectedCategory = ref.read(feedControllerProvider.notifier).categoryId;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Event Nu', style: textTheme.headlineSmall),
        actions: [
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
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.go(AppRoute.search.path),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                user == null ? 'Discover' : 'Discover, ${user.username}',
                style: textTheme.headlineLarge,
              ),
            ),
            if (user != null && !user.isVerified) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            ],
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
            const SizedBox(height: 8),
            const Expanded(child: EventFeed()),
          ],
        ),
      ),
    );
  }
}