import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_colors.dart';
import '../discovery/discovery_providers.dart';

/// Organizer identity chip on the event detail screen.
class OrganizerChip extends ConsumerWidget {
  const OrganizerChip({super.key, required this.organizerId});

  final String organizerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(organizerProvider(organizerId));
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (organizer) => Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.neon.withValues(alpha: 0.18),
                child: Icon(Icons.apartment, size: 15, color: AppColors.neon),
              ),
              const SizedBox(width: 8),
              Text(
                organizer.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (organizer.followerCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${organizer.followerCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder follow affordance; wired to the API in the social phase.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.organizerId, required this.followedByMe});

  final String organizerId;
  final bool followedByMe;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Following organizers is coming soon.')),
        );
      },
      child: Text(followedByMe ? 'Following' : 'Follow'),
    );
  }
}