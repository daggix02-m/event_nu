---
name: Event Nu Design System
colors:
  surface: '#141217'
  surface-dim: '#141217'
  surface-bright: '#3b383e'
  surface-container-lowest: '#0f0d12'
  surface-container-low: '#1d1b20'
  surface-container: '#211f24'
  surface-container-high: '#2b292e'
  surface-container-highest: '#363439'
  on-surface: '#e7e0e8'
  on-surface-variant: '#cac4d0'
  inverse-surface: '#e7e0e8'
  inverse-on-surface: '#322f35'
  outline: '#948f9a'
  outline-variant: '#49454f'
  surface-tint: '#d0bcff'
  primary: '#e9ddff'
  on-primary: '#37265e'
  primary-container: '#d0bcff'
  on-primary-container: '#594983'
  inverse-primary: '#665590'
  secondary: '#feb59d'
  on-secondary: '#502314'
  secondary-container: '#6e3b2a'
  on-secondary-container: '#eea790'
  tertiary: '#bfe8ff'
  on-tertiary: '#003547'
  tertiary-container: '#78d1fb'
  on-tertiary-container: '#005975'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#d0bcff'
  on-primary-fixed: '#210f48'
  on-primary-fixed-variant: '#4d3d76'
  secondary-fixed: '#ffdbd0'
  secondary-fixed-dim: '#feb59d'
  on-secondary-fixed: '#360f03'
  on-secondary-fixed-variant: '#6b3928'
  tertiary-fixed: '#c0e8ff'
  tertiary-fixed-dim: '#78d1fb'
  on-tertiary-fixed: '#001f2b'
  on-tertiary-fixed-variant: '#004d66'
  background: '#141217'
  on-background: '#e7e0e8'
  surface-variant: '#363439'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 44px
    fontWeight: '700'
    lineHeight: 52px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 30px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  gutter-mobile: 1rem
  margin-mobile: 1.25rem
  bottom-nav-clearance: 5.5rem
---

## Brand & Style

This design system drives a mobile-first Progressive Web App designed to capture the electric pulse, nightlife, and cultural underground of Addis Ababa ("Find yourz"). The brand identity balances high-velocity metropolitan discovery with an immersive night-mode lounge ambiance.

### Visual Language & Aesthetic
The visual signature merges **Neon-Violet Material You (M3)** with tactile **Frosted Glassmorphism**. Dark surfaces are deeply saturated with rich obsidian-violet undertones rather than clinical grays, setting off luminous lavender gradients, soft peach event tags, and vibrant sky-blue micro-moments. The interface acts as a cinematic viewfinder for the city: dark stages, translucent overlays, diffused ambient glows, and illuminated borders that guide discovery effortlessly with one hand.

## Colors

The palette is strictly dark-mode-first, relying on nuanced tonal shifts in deep obsidian-purple to construct visual order and depth without high-strain stark whites.

### Palette Architecture
- **Base Background (`neutral_color_hex`: `#151318`)**: An ultra-dark, violet-infused slate that grounds the entire PWA canvas.
- **Primary Lavender Axis (`#d0bcff` to `#a078ff`)**: Linear gradients and solid lavender accents anchor main actions, active states, and focal UI highlights.
- **Peach Accent (`secondary_color_hex`: `#ffb69e`)**: Warm coral-peach used exclusively for tickets, live status flags, and hot scene alerts.
- **Sky Blue Accent (`tertiary_color_hex`: `#7cd5ff`)**: Crisp cyan-blue dedicated to temporal and spatial anchors—venues, geolocation tags, and timestamps.
- **Surfaces & Overlays**:
  - `surface-glass`: `rgba(28, 24, 34, 0.72)` with active backdrop blur.
  - `surface-container-high`: `rgba(43, 37, 51, 0.65)`.
  - `outline-glass`: `rgba(208, 188, 255, 0.16)` shifting to `rgba(208, 188, 255, 0.45)` on active focus.

## Typography

Typography establishes an intentional contrast between energetic, tech-forward city curation and effortless readability.

- **Headlines & Display (Space Grotesk)**: Chosen for its futuristic geometry and sharp quirks, lending swagger to event headlines, artist rosters, and district titles.
- **Body & Labels (Inter)**: Delivers clear legibility across dark backgrounds and frosted overlays, keeping dense event logistics, dates, and navigation crisp at any size.
- Ensure all headline styles use negative tracking to maintain punchiness, while compact labels use expanded tracking for legibility against translucent surfaces.

## Layout & Spacing

A strictly mobile-first layout engine built on an 8pt rhythmic grid, with a 4pt sub-grid for badges, chips, and micro-alignments.

### Grid & Viewport Mechanics
- **Mobile Handheld (360px – 480px)**: 4-column fluid layout with `1.25rem` screen margins and `1rem` gutters. Content scrolls vertically with edge-to-edge bleed options for visual discovery carousels.
- **Safe Area Insets**: Standard `env(safe-area-inset-bottom)` combined with `bottom-nav-clearance` (`5.5rem`) ensures zero collision with the floating pill bottom navigation and system home indicators.
- **Tablet / Large Breakpoint (768px+)**: Restrained single-column or 2-column feed centered with a strict max-width of `640px` to maintain the focused handheld phone aesthetic across responsive web viewports.

## Elevation & Depth

Depth in this system avoids heavy, light-mode drop shadows. Instead, it relies on backdrop filtration, layered opacity tiers, and directional neon light blooms.

### Elevation Hierarchy
1. **Level 0 (Canvas)**: Solid `#151318`. Zero blur.
2. **Level 1 (Card & Content Blocks)**: Glass surface `rgba(28, 24, 34, 0.70)` with `backdrop-filter: blur(16px)` and a subtle ambient stroke `rgba(208, 188, 255, 0.12)`.
3. **Level 2 (Popovers, Sticky Sheet)**: Glass surface `rgba(37, 31, 46, 0.85)` with `backdrop-filter: blur(24px)` and drop shadow `0 8px 32px rgba(0, 0, 0, 0.45)`.
4. **Level 3 (Floating Pill Bar & Dynamic Modals)**: Glass surface `rgba(24, 20, 30, 0.88)` with `backdrop-filter: blur(28px)`, outer border `rgba(208, 188, 255, 0.28)`, and violet glow: `0 4px 24px rgba(160, 120, 255, 0.20)`.

### Glowing Accents
Active elements (such as selected filters, live beacons, and camera triggers) emit a localized radiant outer shadow: `box-shadow: 0 0 16px rgba(160, 120, 255, 0.45)`.

## Shapes

The design system uses a pill-shaped roundedness model (`3`), bringing friendly ergonomics to one-handed thumb navigation and framing frosted cards like pocket lenses into Addis Ababa's scenes.

### Radius Assignments
- **Chips, Badges, Search Bars, Floating Pill Nav**: Fully pill-shaped (`border-radius: 9999px` or `2rem`).
- **Feature Cards & Modals**: `rounded-lg` (`2rem` / `32px`) to preserve a soft silhouette over fluid backgrounds.
- **Inner Elements & Media Previews**: `rounded-md` (`1rem` / `16px`) for clean nested nesting harmony.

## Components

### Buttons
- **Primary CTA**: Lavender gradient (`linear-gradient(135deg, #d0bcff 0%, #a078ff 100%)`), text `#151318` Space Grotesk Bold, fully pill-shaped. Emits soft lavender glow on press.
- **Secondary**: Frosted dark glass with `1px` border `rgba(208, 188, 255, 0.25)`, text `#d0bcff`.
- **Tertiary / Ghost**: Transparent base with text `#d0bcff` or `#ffb69e`.

### Frosted Glassmorphic Event Cards
- Built with Level 1 elevation: `backdrop-filter: blur(16px)`, `rgba(28, 24, 34, 0.70)`, and border `rgba(208, 188, 255, 0.14)`.
- Features full-bleed photographic hero with a bottom-to-top gradient mask (`to #151318`).
- Category chips and date badges float over the media header using frosted capsules.

### Floating Pill Bottom Bar & Center Camera Button
- **Bar**: Centered pill suspended `1rem` above the bottom edge, max width `360px`, width `calc(100% - 2.5rem)`. Elevated with glassmorphism blur (`28px`), dark violet tint, and perimeter neon border.
- **Center "Moment / Camera" Button**: Elevated circular node nested inside the bar, breaking the upper edge by `12px`. Features a primary lavender gradient surface, glowing aura (`box-shadow: 0 0 20px rgba(160, 120, 255, 0.5)`), and high-contrast camera/lens glyph.

### Chips & Badges
- Fully rounded pills with `label-md` or `label-sm` typography.
- **Active State**: Violet gradient background with dark slate label.
- **Default State**: Glass surface `rgba(255, 255, 255, 0.06)` with faint lavender outline.
- **Live / Trending Status**: Tinted with `#ffb69e` (Peach) text and pulsing peach dot indicator.

### Input Fields & Search
- Full pill containers with background `rgba(32, 27, 40, 0.8)` and border `1px solid rgba(208, 188, 255, 0.16)`.
- Left-aligned glowing icon (Search/Filter), placeholder in `rgba(208, 188, 255, 0.45)`.
- Transitions to glowing violet outline (`#a078ff`) upon focus.

### Lists & Venue Rows
- Edge-to-edge items with subtle horizontal separators composed of `rgba(208, 188, 255, 0.08)`.
- Left side features rounded-md preview thumbnail (`48px x 48px`), right side hosts secondary sky-blue distance and time indicators.