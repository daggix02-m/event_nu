import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../profile_providers.dart';

/// A row of tappable counters for Going / Saved / Tickets / Badges.
class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileStatsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        children: [
          _StatCell(
            key: const ValueKey('stat-going'),
            icon: Icons.event_available,
            count: stats.going,
            label: 'Going',
            onTap: () => context.go(AppRoute.myRsvps.path),
          ),
          _StatCell(
            key: const ValueKey('stat-saved'),
            icon: Icons.bookmark_outline,
            count: stats.saved,
            label: 'Saved',
            onTap: () => context.go(AppRoute.saves.path),
          ),
          _StatCell(
            key: const ValueKey('stat-tickets'),
            icon: Icons.confirmation_number_outlined,
            count: stats.tickets,
            label: 'Tickets',
            onTap: () => context.go(AppRoute.myTickets.path),
          ),
          _StatCell(
            key: const ValueKey('stat-badges'),
            icon: Icons.emoji_events_outlined,
            count: stats.badges,
            label: 'Badges',
            onTap: () => DefaultTabController.of(context).animateTo(3),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: AppSpace.xs),
              Text(
                '$count',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}