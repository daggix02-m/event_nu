# Phase 28: Home Upgrade — Featured Carousel + Category Shelves

## Overview
Upgrade the Flutter home screen to match the web app's Discover page structure while preserving existing layout. Two additions:
1. Auto-advancing featured carousel (replaces static HeroMarquee with dynamic PageView)
2. Per-category horizontal event shelves above the flat feed

## Constraints
- **UI/UX preservation:** Every existing icon, button position, and background animation stays untouched
- **Structural refinement only:** Shelves section inserted between CategoryPills and EventFeed; carousel replaces HeroMarquee's internal logic but preserves its fallback behavior
- **Backend:** All data from existing `GET /api/v1/events` endpoint; no new backend calls needed
- **Backend plan swap:** When the planned `GET /api/v1/events/featured` endpoint lands (Phase 32), the carousel will swap to it via a single repository method change

## Tasks

### Task 1: Featured Carousel Widget
**File:** `flutter/lib/features/discovery/widgets/featured_carousel.dart`

- `FeaturedCarousel` widget: takes `List<Event>` of events with posters
- `PageView` with auto-advance (3000ms `Timer`, pauses on touch/swipe)
- Per-slide progress fill bar (bottom dots, animated `Container`)
- Left/right tap zones (1/3 screen width each)
- Swipe gesture support
- Category chip + ENDED chip overlay
- Price chip overlay
- **Fallback:** When <2 events with poster/teaser, renders `HeroMarquee` (existing) instead
- Pauses auto-advance on touch interaction
- Uses existing `AppColors` / `AppSpace` design tokens

### Task 2: Category Shelf Widget
**File:** `flutter/lib/features/discovery/widgets/category_shelf.dart`

- `CategoryShelf` widget: takes `Category` + `List<Event>` (max 8)
- Horizontal snap-scroll `ListView.separated` of compact cards
- Header with slug-mapped icon avatar (web `CATEGORY_ICONS` pattern) + category name + "See all" pill
- Each card: poster thumbnail, title, `whenLabel`, `priceLabel`
- Tapping "See all" navigates to feed filtered by category
- `clipBehavior: Clip.none` to allow edge overflow

### Task 3: Category Shelf Section Provider
**File:** `flutter/lib/features/discovery/widgets/category_shelf_section.dart`

- `CategoryShelfSection` widget that fetches top-level categories (first 6) + their events
- Parallel fetches via a single `AsyncNotifier` per category
- Reuses `DiscoveryRepository.listEvents` with `categoryId` param
- Renders `CategoryShelf` per category
- Hidden when loading; skeleton placeholders

### Task 4: Integration into HomeScreen
**File:** `flutter/lib/features/home/home_screen.dart`

- Replace static `HeroMarquee` in `headers` list with `FeaturedCarousel` (passing first 8 events with posters)
- Insert `CategoryShelfSection` between `CategoryPills` and `EventFeed`
- All existing widgets/icons/positions stay identical

## Acceptance Criteria
- [x] Carousel auto-advances every 3s, pauses on touch, supports swipe
- [x] Carousel shows progress bar with animated fill per slide
- [x] Carousel falls back to existing `HeroMarquee` when <2 events
- [x] Category shelves render with icon avatars and "See all" pills
- [x] "See all" navigates to feed filtered by that category
- [x] Shelves are hidden during loading (no visual jump)
- [x] All existing home icons/buttons/positions are byte-identical
- [x] `flutter analyze` passes
- [x] `flutter test` passes (existing 15 + any new tests)

## Files likely touched
- `flutter/lib/features/discovery/widgets/featured_carousel.dart` (new)
- `flutter/lib/features/discovery/widgets/category_shelf.dart` (new)
- `flutter/lib/features/discovery/widgets/category_shelf_section.dart` (new)
- `flutter/lib/features/home/home_screen.dart` (modify headers list)

## Estimated scope
Small: 3 new files + 1 modified file

## Verification
- `flutter analyze` — 0 issues
- `flutter test` — all pass
- Manual: home screen renders carousel with auto-advance, shelves with icons, existing nav/icons/positions unchanged
