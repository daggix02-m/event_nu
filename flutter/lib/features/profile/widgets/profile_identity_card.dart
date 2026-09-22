import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../auth/data/user.dart';
import '../profile_providers.dart';

/// The profile header: avatar, username, verification badge and bio.
class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final me = ref.watch(meProvider);
    return me.when(
      loading: () => const _IdentitySkeleton(),
      error: (_, _) => _IdentityError(onRetry: () => ref.invalidate(meProvider)),
      data: (user) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileAvatar(user: user),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: AppSpace.xs),
                        const _VerifiedChip(),
                      ],
                    ],
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      user.bio,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Member since ${DateFormat('MMMM yyyy').format(user.createdAt)}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final initial = user.username.isEmpty ? '?' : user.username[0].toUpperCase();
    Widget child;
    if (user.photoUrl.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          user.photoUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialLetter(initial),
        ),
      );
    } else {
      child = _initialLetter(initial);
    }
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }

  Widget _initialLetter(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.onPrimaryContainer,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            'Verified',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: _SkeletonBox(circle: true),
          ),
          SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 140, height: 20),
                SizedBox(height: AppSpace.sm),
                _SkeletonBox(width: 220, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, this.height, this.circle = false});

  final double? width;
  final double? height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(AppRadius.sm),
        color: AppColors.surfaceContainerHighest,
      ),
    );
  }
}

class _IdentityError extends StatelessWidget {
  const _IdentityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load your profile.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}