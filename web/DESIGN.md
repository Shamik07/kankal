---
name: Kankal Web Starter
description: A neutral, replaceable workspace UI built from local shadcn/ui components.
colors:
  background: "hsl(0 0% 99%)"
  foreground: "hsl(222 15% 14%)"
  card: "hsl(0 0% 100%)"
  primary: "hsl(222 15% 18%)"
  primary-foreground: "hsl(0 0% 98%)"
  muted: "hsl(220 14% 95%)"
  muted-foreground: "hsl(220 8% 43%)"
  destructive: "hsl(0 68% 43%)"
  border: "hsl(220 13% 88%)"
  ring: "hsl(222 10% 42%)"
typography:
  body:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
  heading:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1.875rem"
    fontWeight: 600
    lineHeight: 1.2
rounded:
  control: "0.5rem"
  card: "0.875rem"
spacing:
  control-inset: "0.75rem"
  card-inset: "1.5rem"
  section-gap: "2rem"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.primary-foreground}"
    rounded: "{rounded.control}"
    padding: "0.5rem 1rem"
    height: "2.25rem"
  input:
    backgroundColor: "{colors.card}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.control}"
    padding: "0.25rem 0.75rem"
    height: "2.25rem"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.card}"
    padding: "{spacing.card-inset}"
---

## Overview

This is a replaceable demo style for a working application starter. The user chose a neutral, polished workspace. Calm surfaces, clear labels, and restrained controls keep the sample flows easy to adapt to a new product. The `/ui` route previews the reusable presentation components.

## Colors

The interface uses a near-white page, white cards, charcoal primary actions, and a muted slate text scale. Destructive actions use red. Use the CSS role variables in `src/index.css` rather than copying color literals into new screens. The current demo has a light theme only.

## Typography

The starter uses the system UI font stack. Page headings are semibold and clearly larger than body copy. Labels remain visible above fields. Muted text supports the main task but keeps readable contrast.

## Layout

Application content is centered within a `max-w-6xl` container. The sign-in form stays narrow and centered; the item cards move from one column to two at `sm` and three at `lg`. The showcase moves from one column to two at `lg`. Keep primary actions visible without horizontal scrolling at 320px and wider.

## Elevation & Depth

Cards use a fine border on a white surface. Controls may use a small shadow, but cards stay flat. Dialogs use an overlay to focus a confirmation or short editor task.

## Shapes

Controls use small rounded corners; cards and dialog panels are slightly softer. Keep radii consistent through the CSS radius variable and the shared components.

## Components

Use the local shadcn/ui Button, Input, Textarea, Label, Card, Alert, Dialog, and Tabs components. Shared `LoadingState`, `EmptyState`, and `ErrorState` cover content transitions. Keep navigation and API behavior in application code. Dialogs trap focus, buttons expose disabled states, and errors use an alert role; sample states are visible on `/ui`.

The keyboard skip link becomes visible on focus and moves focus to the page's main content. Unexpected render errors use a generic recovery screen with no raw error details.

## Do's and Don'ts

- Do label simulated showcase actions plainly.
- Do keep one primary action clear on each screen and provide a next step in empty and error states.
- Do inspect narrow and wide views and keyboard focus after UI changes.
- Don't imply that showcase form values persist.
- Don't treat this neutral palette as a permanent brand for copied products.
