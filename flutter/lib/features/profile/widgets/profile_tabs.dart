import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../engagement/engagement_providers.dart';
import '../../social/social_providers.dart';
import '../../tickets/ticket_providers.dart';
import '../data/profile_badge.dart';
import '../profile_providers.dart';

class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      tabs: [
        Tab(key: ValueKey('tab-going'), text: 'Going'),
        Tab(key: ValueKey('tab-saved'), text: 'Saved'),
        Tab(key: ValueKey('tab-tickets'), text: 'Tickets'),
        Tab(key: ValueKey('tab-badges'), text: 'Badges'),
      ],
    );
  }
}

/// The [TabBarView] holding each tab's summary list.
class ProfileTabViews extends StatelessWidget {
  const ProfileTabViews({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBarView(
      children: [
        _GoingTab(),
        _SavedTab(),
        _TicketsTab(),
        _BadgesTab(),
      ],
    );
  }
}

class _GoingTab extends ConsumerWidget {
  const _GoingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final going = ref.watch(myRsvpsControllerProvider);
    return going.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        onRetry: () => ref.invalidate(myRsvpsControllerProvider),
      ),
      data: (rsvps) {
        if (rsvps.isEmpty) {
          return const _TabEmpty(
            icon: Icons.event_available,
            title: 'No RSVPs yet',
            subtitle: 'Events you go to will show up here.',
          );
        }
        final preview = rsvps.where((r) => r.isVisible).take(5).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(myRsvpsControllerProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpace.bottomNavClearance),
            children: [
              for (final rsvp in preview)
                ListTile(
                  leading: const _ItemIcon(Icons.event_available),
                  title: Text(rsvp.summary?.title ?? 'Unavailable event'),
                  subtitle: rsvp.summary == null
                      ? null
                      : Text(
                          DateFormat('EEE, MMM d · h:mm a')
                              .format(rsvp.summary!.startsAt.toLocal()),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: rsvp.isVisible
                      ? () => context.go(AppRoute.event(rsvp.eventId))
                      : null,
                ),
              _SeeAllTile(
                key: const ValueKey('see-all-going'),
                label: 'All going events',
                onTap: () => context.go(AppRoute.myRsvps.path),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(mySavesControllerProvider);
    return saved.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        onRetry: () => ref.invalidate(mySavesControllerProvider),
      ),
      data: (saves) {
        if (saves.isEmpty) {
          return const _TabEmpty(
            icon: Icons.bookmark_outline,
            title: 'No saves yet',
            subtitle: 'Bookmark events you like and they will appear here.',
          );
        }
        final preview = saves.where((s) => s.isVisible).take(5).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(mySavesControllerProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpace.bottomNavClearance),
            children: [
              for (final save in preview)
                ListTile(
                  leading: const _ItemIcon(Icons.bookmark_outline),
                  title: Text(save.summary?.title ?? 'Unavailable event'),
                  subtitle: save.summary == null
                      ? null
                      : Text(
                          DateFormat('EEE, MMM d · h:mm a')
                              .format(save.summary!.startsAt.toLocal()),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: save.isVisible
                      ? () => context.go(AppRoute.event(save.eventId))
                      : null,
                ),
              _SeeAllTile(
                key: const ValueKey('see-all-saved'),
                label: 'All saved events',
                onTap: () => context.go(AppRoute.saves.path),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketsTab extends ConsumerWidget {
  const _TicketsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(myTicketsControllerProvider);
    return tickets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        onRetry: () => ref.invalidate(myTicketsControllerProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _TabEmpty(
            icon: Icons.confirmation_number_outlined,
            title: 'No tickets yet',
            subtitle: 'Tickets you buy will live here.',
          );
        }
        final preview = items.take(5).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(myTicketsControllerProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpace.bottomNavClearance),
            children: [
              for (final ticket in preview)
                ListTile(
                  leading: const _ItemIcon(Icons.confirmation_number_outlined),
                  title: Text(ticket.isUsed ? 'Used ticket' : 'Valid ticket'),
                  subtitle: Text(
                    'Issued ${DateFormat('MMM d').format(ticket.issuedAt.toLocal())}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoute.myTickets.path),
                ),
              _SeeAllTile(
                key: const ValueKey('see-all-tickets'),
                label: 'All my tickets',
                onTap: () => context.go(AppRoute.myTickets.path),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgesTab extends ConsumerWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    return badges.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _TabError(
        onRetry: () => ref.invalidate(badgesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _TabEmpty(
            icon: Icons.emoji_events_outlined,
            title: 'No badges yet',
            subtitle: 'RSVP, attend, buy a ticket or share a moment to earn one.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(badgesProvider.future),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.bottomNavClearance,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpace.md,
              crossAxisSpacing: AppSpace.md,
              childAspectRatio: 1.1,
            ),
            itemCount: list.length,
            itemBuilder: (_, index) => _BadgeCard(badge: list[index]),
          ),
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(badge.icon, size: 26, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Earned ${DateFormat('MMMM yyyy').format(badge.earnedAt)}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceContainerHigh,
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
  }
}

class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.primary,
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

class _TabEmpty extends StatelessWidget {
  const _TabEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpace.sm),
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabError extends StatelessWidget {
  const _TabError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load this list.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}