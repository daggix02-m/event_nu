import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../social/data/social_models.dart';
import '../social/social_providers.dart';

/// The signed-in user's save folders. Create/rename/delete mutate local state
/// immediately after the backend call succeeds, and are reflected across the
/// whole app because the chip row and the move sheet watch this provider.
final saveFoldersControllerProvider =
    AsyncNotifierProvider<SaveFoldersController, List<SaveFolder>>(
  SaveFoldersController.new,
);

class SaveFoldersController extends AsyncNotifier<List<SaveFolder>> {
  @override
  Future<List<SaveFolder>> build() async {
    return ref.watch(socialRepositoryProvider).mySaveFolders();
  }

  Future<SaveFolder> create(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) throw ArgumentError('Folder name cannot be empty.');
    final folder = await ref.watch(socialRepositoryProvider).createSaveFolder(name);
    state = AsyncData(List<SaveFolder>.of(state.value ?? const [])..add(folder));
    return folder;
  }

  Future<void> rename(String id, String rawName) async {
    final name = rawName.trim();
    final updated =
        await ref.watch(socialRepositoryProvider).renameSaveFolder(id, name);
    state = AsyncData([
      for (final folder in state.value ?? const <SaveFolder>[])
        if (folder.id == id) updated else folder,
    ]);
  }

  Future<void> delete(String id) async {
    await ref.watch(socialRepositoryProvider).deleteSaveFolder(id);
    state = AsyncData([
      for (final folder in state.value ?? const <SaveFolder>[])
        if (folder.id != id) folder,
    ]);
  }
}