# Phase 31: Save Folders UI

## Overview
Add folder management to the My Saves screen: create, rename, delete folders, and move saved events between folders.

## Constraints
- All backend endpoints already exist (`/me/save-folders`, `/events/{id}/save`)
- Existing list layout preserved; folders are an enhancement

## Tasks

### Task 1: Folders Data Layer
**File:** `flutter/lib/features/saves/saves_providers.dart`

- `saveFoldersControllerProvider` — list/create/rename/delete folders
- Extend `mySavesControllerProvider` with `moveToFolder` method

### Task 2: Folder Chips Row
**File:** `flutter/lib/features/saves/widgets/folder_chips.dart`

- Horizontal chip row: All / Uncategorized / custom folders
- "New folder" action chip
- Long-press on folder chip → rename/delete menu

### Task 3: Move-to-Folder Sheet
**File:** `flutter/lib/features/saves/widgets/move_to_folder_sheet.dart`

- Bottom sheet listing folders for a selected save
- Tap to move; confirmation snackbar

### Task 4: My Saves Screen Update
**File:** `flutter/lib/features/saves/my_saves_screen.dart`

- Add folder chips row at top
- Group saves by selected folder
- Long-press save tile → "Move to folder" option

## Acceptance Criteria
- [x] Folder chips row renders at top of My Saves
- [x] "New folder" creates a folder (backend call)
- [x] Long-press save tile shows move option
- [x] Move-to-folder bottom sheet works
- [x] Existing list layout preserved
- [x] `flutter analyze` passes
- [x] `flutter test` passes
