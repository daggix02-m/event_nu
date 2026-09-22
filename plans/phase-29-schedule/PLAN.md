# Phase 29: Schedule Page + Discover/Schedule Segmented Control

## Overview
Add a Schedule page (30-day date rail + time-of-day filters) reachable via a segmented control on the Home screen, without modifying the fixed bottom navigation bar.

## Constraints
- Bottom nav bar `FloatingNavBar` is untouched (Home/Map/Camera/Saves/Profile)
- Segmented control is an **addition** below the "Discover, {username}" heading
- Uses existing `GET /api/v1/events` with `date_from`/`date_to` params

## Tasks

### Task 1: Schedule Data Layer
**File:** `flutter/lib/features/schedule/schedule_providers.dart`

- `ScheduleController` AsyncNotifier: fetches events for a selected date range
- Methods: `selectDate(DateTime)`, `setTimeOfDay(TimeOfDay?)`, `loadMore()`
- Filters: All hours, Daylight (6-18), Golden hour (6-9, 16-19), Late night (21-6)
- Reuses `DiscoveryRepository.listEvents`

### Task 2: Date Rail Widget
**File:** `flutter/lib/features/schedule/widgets/date_rail.dart`

- Horizontal 30-day scroller of dates (today..+29)
- Selected date = filled pill (primaryContainer bg), unselected = outlined
- Auto-scroll to today on mount
- Each date shows day abbreviation + date number

### Task 3: Time-of-Day Filter Chips
**File:** `flutter/lib/features/schedule/widgets/time_of_day_filters.dart`

- Row of chips: All hours, Daylight, Golden hour, Late night
- Uses existing chip styling (InputChip pattern from search_screen)

### Task 4: Schedule Event Card
**File:** `flutter/lib/features/schedule/widgets/schedule_event_card.dart`

- Compact row card: event title, date/time, venue, status chip (LIVE/ENDED/SOON)
- Taps navigate to event detail

### Task 5: Schedule Screen
**File:** `flutter/lib/features/schedule/schedule_screen.dart`

- Scaffold with AppBar "Schedule"
- Date rail at top
- Time-of-day filters below
- Event list (or empty state)

### Task 6: Segmented Control on Home
**File:** `flutter/lib/features/home/home_screen.dart`

- Animated `SegmentedButton` (Discover / Schedule) below the "Discover" heading
- Discover shows existing feed; Schedule shows `ScheduleScreen` inline
- Smooth fade transition between views

## Acceptance Criteria
- [x] Discover/Schedule segmented control renders below "Discover" heading
- [x] Schedule view shows 30-day horizontal date rail
- [x] Time-of-day filter chips work
- [x] Schedule event cards render with status chips
- [x] Bottom nav is unchanged
- [x] `flutter analyze` passes
- [x] `flutter test` passes
