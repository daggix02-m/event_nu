import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../social/data/social_models.dart';
import '../../social/social_providers.dart';
import '../saves_providers.dart';

/// Lets a user move one save into a folder (or back to Uncategorized).
/// Performs the move through [MySavesController.moveToFolder] and confirms
/// with a snackbar.
Future<void> showMoveToFolderSheet(
  BuildContext context, {
  required String eventId,
  required String? currentFolderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MoveToFolderSheet(
      eventId: eventId,
      currentFolderId: currentFolderId,
    ),
  );
}

class MoveToFolderSheet extends ConsumerStatefulWidget {
  const MoveToFolderSheet({
    super.key,
    required this.eventId,
    required this.currentFolderId,
  });

  final String eventId;
  final String? currentFolderId;

  @override
  ConsumerState<MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends ConsumerState<MoveToFolderSheet> {
  String? get _current => widget.currentFolderId;

  Future<void> _move(String? folderId, String folderName) async {
    await ref.read(mySavesControllerProvider.notifier).moveToFolder(widget.eventId, folderId);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved to "$folderName"')),
    );
  }

  Future<void> _onError(Object _) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not move this save.')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final folders = ref.watch(saveFoldersControllerProvider).value ?? const <SaveFolder>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.bottomNavClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Text('Move to folder', style: textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _FolderOption(
                    key: const ValueKey('move-option-uncategorized'),
                    name: 'Uncategorized',
                    selected: _current == null,
                    onTap: () => _move(null, 'Uncategorized').catchError(_onError),
                  ),
                  for (final folder in folders)
                    _FolderOption(
                      key: ValueKey('move-option-${folder.id}'),
                      name: folder.name,
                      selected: _current == folder.id,
                      onTap: () => _move(folder.id, folder.name).catchError(_onError),
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

class _FolderOption extends StatelessWidget {
  const _FolderOption({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.folder : Icons.folder_outlined,
        color: selected ? Theme.of(context).colorScheme.primary : AppColors.onSurfaceVariant,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: selected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}