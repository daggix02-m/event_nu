import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_space.dart';
import '../../social/data/social_models.dart';
import '../../social/social_providers.dart';
import '../saves_providers.dart';

/// Sentinel [selected] value meaning "saves with no folder".
const kUncategorizedFolder = '__uncategorized__';

/// Horizontal folder filter: All / Uncategorized / custom folders, plus a
/// "New folder" action. Long-pressing a custom folder opens rename/delete.
class FolderChips extends ConsumerWidget {
  const FolderChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The currently selected folder id, `null` for All or [kUncategorizedFolder]
  /// for saves without a folder.
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(saveFoldersControllerProvider).value ?? const <SaveFolder>[];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: ChoiceChip(
              key: const ValueKey('folder-chip-all'),
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: ChoiceChip(
              key: const ValueKey('folder-chip-uncategorized'),
              label: const Text('Uncategorized'),
              selected: selected == kUncategorizedFolder,
              onSelected: (_) => onSelected(kUncategorizedFolder),
            ),
          ),
          for (final folder in folders)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.xs),
              child: GestureDetector(
                onLongPress: () => _showFolderActions(context, ref, folder),
                child: ChoiceChip(
                  key: ValueKey('folder-chip-${folder.id}'),
                  label: Text(folder.name),
                  selected: selected == folder.id,
                  onSelected: (_) => onSelected(folder.id),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: ActionChip(
              key: const ValueKey('folder-chip-new'),
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New folder'),
              onPressed: () => _createFolderDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolderDialog(BuildContext context, WidgetRef ref) async {
    final name = await _promptFolderName(context, title: 'New folder');
    if (name == null || !context.mounted) return;
    try {
      await ref.read(saveFoldersControllerProvider.notifier).create(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Created "${name.trim()}"')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not create folder.')));
      }
    }
  }

  Future<void> _showFolderActions(
    BuildContext context,
    WidgetRef ref,
    SaveFolder folder,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('folder-action-rename'),
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename folder'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              key: const ValueKey('folder-action-delete'),
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete folder'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _renameFolder(context, ref, folder);
      case 'delete':
        await _deleteFolder(context, ref, folder);
    }
  }

  Future<void> _renameFolder(
    BuildContext context,
    WidgetRef ref,
    SaveFolder folder,
  ) async {
    final name = await _promptFolderName(context, title: 'Rename folder', initial: folder.name);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(saveFoldersControllerProvider.notifier).rename(folder.id, name);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Renamed to "${name.trim()}"')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not rename folder.')));
      }
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    WidgetRef ref,
    SaveFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('"${folder.name}" and its saves become uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(saveFoldersControllerProvider.notifier).delete(folder.id);
      ref.invalidate(mySavesControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${folder.name}"')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not delete folder.')));
      }
    }
  }
}

Future<String?> _promptFolderName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = controller.text;
            if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}