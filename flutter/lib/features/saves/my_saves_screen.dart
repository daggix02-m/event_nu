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
import 'saves_providers.dart';
import 'widgets/folder_chips.dart';
import 'widgets/move_to_folder_sheet.dart';

class MySavesScreen extends ConsumerStatefulWidget {
  const MySavesScreen({super.key});

  @override
  ConsumerState<MySavesScreen> createState() => _MySavesScreenState();
}

class _MySavesScreenState extends ConsumerState<MySavesScreen> {
  /// Selected folder id; null = All, [kUncategorizedFolder] = no folder.
  String? _selected;

  List<SavedEvent> _visible(List<SavedEvent> saves, List<SaveFolder> folders) {
    if (_selected == null) return saves;
    if (_selected == kUncategorizedFolder) {
      return saves.where((s) => s.folderId == null).toList(growable: false);
    }
    if (!folders.any((f) => f.id == _selected)) return saves;
    return saves.where((s) => s.folderId == _selected).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(mySavesControllerProvider);
    final folders = ref.watch(saveFoldersControllerProvider).value ?? const <SaveFolder>[];
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
          final visible = _visible(saves, folders);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(mySavesControllerProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpace.bottomNavClearance),
              children: [
                const SizedBox(height: AppSpace.xs),
                FolderChips(
                  selected: _selected,
                  onSelected: (value) => setState(() => _selected = value),
                ),
                const SizedBox(height: AppSpace.xs),
                if (visible.isEmpty)
                  _FolderEmptyState()
                else if (_selected == null)
                  ..._groupSections(visible)
                else
                  ...visible.map((saved) => _SaveTile(saved: saved)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _groupSections(List<SavedEvent> saves) {
    final grouped = <String, List<SavedEvent>>{};
    for (final save in saves) {
      final folder = save.folderId == null ? 'Uncategorized' : 'Folders';
      grouped.putIfAbsent(folder, () => []).add(save);
    }
    return [
      for (final entry in grouped.entries) ...[
        Padding(
          key: ValueKey('section-${entry.key}'),
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 0),
          child: Text(
            entry.key,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        ...entry.value.map((saved) => _SaveTile(saved: saved)),
      ],
    ];
  }
}

class _FolderEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        children: [
          const Icon(Icons.folder_outlined, size: 40, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppSpace.sm),
          Text('No saves in this folder',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
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
        key: ValueKey('save-tile-${saved.eventId}'),
        onTap: () {
          if (visible) context.go(AppRoute.event(saved.eventId));
        },
        onLongPress: () => _saveActions(context, ref),
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
          onPressed: () => _removeSave(context, ref),
        ),
      ),
    );
  }

  Future<void> _saveActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('save-action-move'),
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move to folder'),
              onTap: () => Navigator.pop(sheetContext, 'move'),
            ),
            ListTile(
              key: const ValueKey('save-action-remove'),
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Remove save'),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'move':
        await showMoveToFolderSheet(
          context,
          eventId: saved.eventId,
          currentFolderId: saved.folderId,
        );
      case 'remove':
        await _removeSave(context, ref);
    }
  }

  Future<void> _removeSave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(mySavesControllerProvider.notifier).unsave(saved.eventId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove this save.')),
        );
      }
    }
  }
}