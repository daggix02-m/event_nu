import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_engine.dart';
import '../../design/app_colors.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(syncStateControllerProvider);
    final state = value.value;
    if (state == null || !state.offline) return const SizedBox.shrink();
    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      content: Text(
        "You're offline. Showing cached content.",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
      ),
      leading: const Icon(Icons.wifi_off, color: AppColors.onSurfaceVariant),
      actions: [
        TextButton(
          onPressed: () => ref.read(syncStateControllerProvider.notifier).syncNow(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
