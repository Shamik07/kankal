# Flutter UI options

The starter uses Flutter's Material 3 widgets and the local `kankal_ui` package.
This keeps the starter small while giving repeated controls a shared appearance.
Material 3 is the default for new starter screens.

## Reusable coverage today

The local package wraps the Material controls used by this demo:

- `AppButton` provides filled and outlined styles, a busy indicator, and the
  disabled state through a null callback.
- `AppTextField` wraps `TextFormField`. Sign-in and item editing compose it with
  Flutter's native `Form` and validators.
- `AppLoadingIndicator`, `AppEmptyState`, and `AppErrorState` cover common
  loading, no-content, and retryable-error states.
- `AppConfirmationDialog` provides the shared confirmation dialog used when
  deleting an item.

These are the needs of the current mock sign-in and in-memory item example, not
a complete component library. Pagination is deferred: the current item list has
no real paging contract to express.

## Optional `shadcn_ui`

[`shadcn_ui`](https://pub.dev/packages/shadcn_ui) is a viable option for a
separate product that wants its component set and visual system. As listed on
pub.dev on September 24, 2026, version 0.57.1 supports Android, iOS, Linux,
macOS, Web, and Windows. Its component progress list marks buttons, dialogs,
forms, and inputs complete, while pagination is marked incomplete. The package
is still on the 0.x version line and lists many dependencies, including
`flutter_animate`, `flutter_svg`, `intl`, `slang`, `lucide_icons_flutter`, and
other packages. Review its current API and dependency impact before adopting it.

For a copied product that chooses this option:

1. Add the package in that product's Flutter directory with
   `fvm flutter pub add shadcn_ui`.
2. Follow the package's current [installation and usage guide](https://mariuti.com/flutter-shadcn-ui/)
   to configure its app theme.
3. Migrate shared controls and screens to that theme as a deliberate product
   change, then remove the old Material wrappers that are no longer used.

Keep Material 3 as the single default for the starter. Mixing Material and
`shadcn_ui` themes across shared screens can create inconsistent control styling
and interaction patterns. Add `shadcn_ui` to the base starter only if its product
requirements change to justify the added dependency and theme migration.
