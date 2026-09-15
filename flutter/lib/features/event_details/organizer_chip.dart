import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../discovery/discovery_providers.dart';
import '../social/social_providers.dart';

/// Organizer identity chip with a live follow toggle.
class OrganizerChip extends ConsumerStatefulWidget {
  const OrganizerChip({super.key, required this.organizerId});

  final String organizerId;

  @override
  ConsumerState<OrganizerChip> createState() => _OrganizerChipState();
}

class _OrganizerChipState extends ConsumerState<OrganizerChip> {
  bool? _followed;
  int? _followers;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(organizerProvider(widget.organizerId));
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (organizer) {
        final followed = _followed ?? organizer.followedByMe;
        final followers = _followers ?? organizer.followerCount;
        return Material(
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
                if (followers > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$followers',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _toggleFollow(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: followed ? AppColors.neon.withValues(alpha: 0.16) : Colors.transparent,
                      border: Border.all(color: followed ? AppColors.neon : AppColors.outlineVariant),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      followed ? 'Following' : 'Follow',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: followed ? AppColors.neon : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow() async {
    final organizer = ref.read(organizerProvider(widget.organizerId)).value;
    if (organizer == null) return;
    final target = !(_followed ?? organizer.followedByMe);
    setState(() => _followed = target);
    try {
      final state = await ref.read(socialRepositoryProvider).setFollow(widget.organizerId, target);
      if (!mounted) return;
      setState(() {
        _followed = state.followedByMe;
        _followers = state.followerCount;
      });
      ref.invalidate(organizerProvider(widget.organizerId));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _followed = !target);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}