---
name: Kankal Flutter Starter
description: Replaceable Material 3 demo theme and shared UI patterns for the Flutter starter.
colors:
  seed-slate: "#465667"
  light-surface: "#F7F8FA"
  dark-surface: "#111418"
  light-control: "#FFFFFF"
rounded:
  control: "12px"
  card: "16px"
spacing:
  control-inset: "16px"
  button-horizontal: "20px"
components:
  button-filled:
    rounded: "{rounded.control}"
  button-outlined:
    rounded: "{rounded.control}"
  text-field:
    rounded: "{rounded.control}"
    padding: "16px"
  card:
    rounded: "{rounded.card}"
---

## Overview

The current UI package uses Flutter Material 3 as a runnable starter showcase. Its slate seed, surfaces, controls, and component patterns are neutral demo defaults intended to be replaced or adapted by each copied product. Kankal does not set a permanent brand identity for those projects.

**The Replaceable Demo Rule.** Preserve Material's familiar platform behavior while treating the colors and styling in `AppTheme` as starter examples, not a required Kankal brand.

## Colors

The light and dark themes derive their Material `ColorScheme` from a muted slate seed. Material generates the role colors for each brightness; only the seed and explicitly supplied surfaces are fixed here. Use the generated scheme roles through the theme instead of hard-coding approximations. Light scaffolds use the pale neutral surface and controls/cards use white. Dark scaffolds use the deep charcoal surface; controls and cards use Material's elevated surface roles.

## Typography

`AppTheme` starts from Flutter's `Typography.material2021()` and applies the active scheme's on-surface color to body and display text. No custom font family or independent type scale is configured. Use the Material text theme roles so platform typography remains consistent.

## Layout

The showcase centers content in a maximum width of 900px. Its scrollable content has 24px horizontal insets, and sections use 20px vertical separation. Button collections wrap with 12px horizontal and vertical gaps. The content-state examples switch from one column to two when their available width exceeds 560px. These are showcase layout examples, not app-wide responsive mandates.

The sign-in route keeps one Stacked ViewModel and shared form while selecting compact or wide composition at 720 logical pixels. Split future screens into layout widgets only when their composition actually differs; use available width rather than platform names.

## Elevation & Depth

Cards are flat (zero elevation) and use an outline-variant border. Surfaces and controls rely on Material 3 color roles rather than custom shadows.

## Shapes

Buttons and form fields use 12px corners. Cards use 16px corners. Keep these values aligned through `AppTheme` when retaining this starter theme.

## Components

- **Filled and outlined buttons:** `AppButton` supports both Material variants, an optional 18px leading icon, busy progress, disabled state, and optional full-width expansion. The theme sets a 52px minimum height, 20px horizontal padding, and semibold label weight. Busy buttons disable their callback and expose a live semantic state.
- **Text fields:** `AppTextField` uses Material form validation and keyboard behavior, with optional hint, icons, autofill, and obscured input. Theme decoration supplies filled backgrounds, 16px insets, and 12px corners; focused borders use a 2px primary outline.
- **Cards:** Theme cards have no elevation, zero outer margin, a one-pixel outline-variant border, and 16px corners. Light cards are white; dark cards use the low surface-container role.
- **Confirmation dialogs:** `AppConfirmationDialog` uses Material's alert layout with caller-owned actions. Destructive confirmation uses the active scheme's error and on-error colors; both actions keep at least 48px touch targets.
- **Loading, empty, and error states:** Shared state widgets center their content with 24px padding. Empty and error messages use the Material text theme; optional actions remain caller supplied. Loading uses a compact 28px progress indicator.

## Do's and Don'ts

- Do use `Theme.of(context).colorScheme` and `textTheme` roles so light and dark themes stay coordinated.
- Do treat this palette and these component values as replaceable defaults when adapting the starter.
- Do keep loading, empty, and error content actionable and semantically labeled where the shared widgets provide that behavior.
- Don't describe the slate seed as a fixed product brand or assume copied projects must retain it.
- Don't add a custom font or extra colors as if they were already part of this UI package.
