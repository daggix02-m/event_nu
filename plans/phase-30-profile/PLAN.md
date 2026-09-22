# Phase 30: Profile Overhaul

## Overview
Replace the stub "Make it yours" Profile screen with a real profile page showing user identity, stats, and tabs into existing Going/Saved/Tickets/Badges screens.

## Constraints
- AppBar "Your profile" title stays
- Route `/profile` stays
- All data from existing endpoints (`/users/me`, `/me/rsvps`, `/me/saves`, `/me/tickets`, `/me/badges`)
- Moments and reviews remain on event detail (no change)

## Tasks

### Task 1: Profile Data Layer
**File:** `flutter/lib/features/profile/profile_providers.dart`

- `meProvider` — `GET /api/v1/users/me`
- `badgesProvider` — `GET /api/v1/users/me/badges`
- Stats derived from existing providers (rsvp count, save count, ticket count)

### Task 2: Profile Identity Card
**File:** `flutter/lib/features/profile/widgets/profile_identity_card.dart`

- Gradient avatar circle (existing style), username, verified chip if applicable
- Bio/location if available from `/users/me`

### Task 3: Profile Stats Row
**File:** `flutter/lib/features/profile/widgets/profile_stats_row.dart`

- Row of stat chips: Going (count), Saved (count), Tickets (count), Badges (count)
- Tapping each navigates to the corresponding screen

### Task 4: Profile Tabs
**File:** `flutter/lib/features/profile/widgets/profile_tabs.dart`

- TabBar: Going / Saved / Tickets / Badges
- Each tab shows a summary list linking to the full screen
- Badges tab shows badge grid from `/users/me/badges`

### Task 5: Profile Screen Rewrite
**File:** `flutter/lib/features/profile/profile_screen.dart`

- Replace stub body with: Identity card + Stats row + Tabs
- Pull-to-refresh
- Loading/error states

## Acceptance Criteria
- [x] Profile shows identity card with avatar, username
- [x] Stats row shows Going/Saved/Tickets/Badges counts
- [x] Tabs navigate to existing screens
- [x] Badges tab shows badge grid
- [x] `flutter analyze` passes
- [x] `flutter test` passes
