import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_router.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import '../../shared/widgets/state_views.dart';
import '../social/data/social_models.dart';
import '../social/social_providers.dart';

class MySavesScreen extends ConsumerWidget {
  const MySavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(mySavesControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Saves')),
      body: value.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Could not load your saved events.',
          onRetry: () => ref.invalidate(mySavesControllerProvider),
        ),
        data: (saves) {
          if (saves.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border,
              title: 'Nothing saved yet',
              message: 'Hit the bookmark on any event to keep it here.',
            );
          }
          final grouped = _groupByFolder(saves);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(mySavesControllerProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 6),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  ...entry.value.map((saved) => _SaveTile(saved: saved)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static Map<String, List<SavedEvent>> _groupByFolder(List<SavedEvent> saves) {
    final result = <String, List<SavedEvent>>{};
    for (final save in saves) {
      final folder = save.folderId ?? 'All saves';
      result.putIfAbsent(folder, () => []).add(save);
    }
    return result;
  }
}

class _SaveTile extends ConsumerWidget {
  const _SaveTile({required this.saved});

  final SavedEvent saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final title = saved.summary?.title;
    final visible = saved.isVisible;
    return Card(
      color: AppColors.surfaceContainer,
      child: ListTile(
        onTap: () {
          if (visible) context.go(AppRoute.event(saved.eventId));
        },
        leading: CircleAvatar(
          backgroundColor: AppColors.neon.withValues(alpha: 0.16),
          child: Icon(visible ? Icons.event : Icons.visibility_off, color: AppColors.neon, size: 20),
        ),
        title: Text(
          visible && title != null && title.isNotEmpty ? title : 'Unavailable event',
          style: textTheme.titleSmall?.copyWith(color: visible ? AppColors.onSurface : AppColors.onSurfaceVariant),
        ),
        subtitle: saved.summary == null
            ? null
            : Text(
                DateFormat('EEE, MMM d · h:mm a').format(saved.summary!.startsAt.toLocal()),
                style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark_remove_outlined, color: AppColors.error),
          tooltip: 'Remove save',
          onPressed: () async {
            try {
              await ref.read(mySavesControllerProvider.notifier).unsave(saved.eventId);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not remove this save.')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}