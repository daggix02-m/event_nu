import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../design/app_colors.dart';
import '../../moments/share_moment_sheet.dart';
import '../../../shared/widgets/glass.dart';

/// The floating pill bottom bar: Home · Map · [camera] · Saves · Profile.
///
/// The center node is a raised gradient button that opens the share-moment
/// sheet bound to the [heroEventId] event. When no event is available yet the
/// button stays honest with a helpful snackbar instead of a dead-end.
class FloatingNavBar extends ConsumerWidget {
  const FloatingNavBar({super.key, this.heroEventId});

  final String? heroEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          widthFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Glass(
              blur: 28,
              tint: const Color(0xE018141E),
              borderColor: const Color(0x47D0BCFF),
              shadow: const BoxShadow(
                color: Color(0x33A078FF),
                blurRadius: 24,
                offset: Offset(0, 4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                key: const ValueKey('floating-nav'),
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Slot(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    active: true,
                    onTap: () => context.go(AppRoute.home.path),
                  ),
                  _Slot(
                    icon: Icons.map_outlined,
                    label: 'Map',
                    onTap: () => context.go(AppRoute.map.path),
                  ),
                  _CameraButton(onTap: () => _onCamera(context)),
                  _Slot(
                    icon: Icons.bookmark_outline,
                    label: 'Saves',
                    onTap: () => context.go(AppRoute.saves.path),
                  ),
                  _Slot(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () => context.go(AppRoute.profile.path),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCamera(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final eventId = heroEventId;
    if (eventId == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No event to tag yet — share it when one is live.'),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ShareMomentSheet(eventId: eventId),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.neon : AppColors.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80A078FF),
              blurRadius: 20,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: const Icon(
          Icons.photo_camera_outlined,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}