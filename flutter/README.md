# Kankal Flutter

Kankal is a local Flutter demo with mock sign-in and an in-memory item list. It
uses the Flutter SDK version in `.fvmrc` (3.44.6) through FVM.

## Set up and run

Install FVM using its installation instructions if it is not already available.
From this directory, install the pinned SDK, fetch packages, and launch on a
connected device or simulator:

```sh
fvm install 3.44.6
fvm flutter pub get
fvm flutter run
```

To run in Chrome, use `fvm flutter run -d chrome`.

## Try the demo

Both sign-in methods use the same mock account. No email is sent.

| Method | Demo value |
| --- | --- |
| Email | `demo@example.com` |
| Password | `password123` |
| Email code | `123456` |

For email-code sign-in, choose **Email code**, request a code, then enter the
demo value above. The code can only be used after requesting it.

After signing in, create, edit, and delete items in the sample list. Each app
service instance starts with one **Sample item**. Items and sessions exist only
in memory and reset when the app process is restarted. Signing out clears the
current session and returns to sign-in.

## Project structure

- `lib/core/` defines the authentication and item API interfaces, their mock
  implementations, and local diagnostics.
- `lib/features/` contains the sign-in, item list, and item editor screens with
  Stacked ViewModels holding their screen logic. The sign-in route keeps one
  ViewModel and shared form while choosing compact or wide layouts by width.
- `lib/app/app.dart` creates the app services and maps named routes in
  `lib/app/routes.dart`.
- `packages/kankal_ui/` is the local presentation package used by the app. Its
  example shows the theme, buttons, fields, confirmation dialog, and loading,
  empty, and error states. Run it from the Flutter directory with:

  ```sh
  cd packages/kankal_ui/example
  fvm flutter pub get
  fvm flutter run -d chrome -t lib/main.dart
  ```

  The starter uses Material 3 by default. See [UI options](docs/ui-options.md)
  for its reusable controls and the optional `shadcn_ui` route.
  The package also has a [Widgetbook workbench](packages/kankal_ui/README.md#widgetbook)
  for isolated component states and light/dark review.

The runtime dependencies are deliberately small: Stacked 3.5 for ViewModels
and the local UI package. Flutter's Material form controls, theme, and Dart's
logging tools cover the rest of this mock version. When a backend contract is
ready, choose an HTTP client for its actual needs. Add secure storage when real
session credentials exist, and a crash or analytics SDK only after selecting a
provider and deciding what data it may receive.

For UI changes, read [PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md), then use
Impeccable's Flutter context and native-platform checks. The slate theme in
`kankal_ui` is a replaceable demo default. Browser previews help inspect layout;
verify iOS and Android appearance on a simulator or device before claiming
those platforms are visually checked.

## Working with coding agents

Start each feature with [the project rules](../AGENTS.md), the affected API
contract, and one observable behavior to add or fix. Ask the agent to show the
failing focused test first, implement that behavior in its owning ViewModel or
service, and rerun the test before the next behavior. Keep route decisions in
the app and reusable presentation in `kankal_ui`. For a changed user journey,
update the integration test and check the relevant native screens. Finish with
the analyzer and formatter commands below. This keeps agent work reviewable
without adding generated scaffolding for features that do not need it.

## Replacing the mock APIs

The app currently has no backend or HTTP contract. See
[the mock API contract](docs/mock-api-contract.md) for the current Dart
behavior to preserve. When a server contract is agreed, implement `AuthApi`
and `ItemsApi` adapters for it and provide them through `AppServices` in
`lib/app/app.dart`. Supplying a non-mock auth adapter removes the demo
credential hints and prefills. Keep screen logic in the ViewModels.

## Diagnostics and limitations

Our structured diagnostics record fixed event names with a source category and
severity. Unexpected errors add only their type and stack, never their message
or form values. This logger does not accept email addresses, passwords, codes,
item contents, or arbitrary event properties. It sends local logs to Dart
DevTools in debug builds; release builds use no-op diagnostics. Flutter's
normal debug error reporter still receives the original exception, so exception
messages must not contain secrets or request data. There is no remote telemetry,
real authentication or email delivery, backend storage, or session persistence.

## Checks

Use a red-green-refactor loop for new behavior: add one observable test, watch
it fail for the intended reason, implement that behavior, then refactor while
it stays green. The list-refresh regression test is an example. Avoid tests
that simply restate code structure.

Run commands from this directory. Focused tests cover the mock APIs; the
integration journey checks both sign-in methods and the create, edit, delete,
and sign-out flow:

```sh
fvm flutter test test/core/auth/mock_auth_api_test.dart
fvm flutter test test/core/items/mock_items_api_test.dart
fvm flutter test test/core/diagnostics/diagnostics_test.dart
fvm flutter test test/features/items/items_view_model_test.dart test/features/items/item_editor_view_model_test.dart test/widget_test.dart
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fvm flutter test integration_test/mock_item_journey_test.dart -d macos
fvm flutter analyze
fvm dart format --output=none --set-exit-if-changed lib test integration_test
```

For another supported integration-test target, replace `macos` with its device
name. For the UI package, run its tests from `packages/kankal_ui` with
`fvm flutter test`.

## Platform runners and automation

The Android runner uses Gradle 8.14, Android Gradle Plugin 8.11.1, and Kotlin
2.2.20. The iOS runner targets iOS 13 or later. The iOS and macOS runners use
Swift Package Manager without CocoaPods for the current dependencies. A future
plugin that supports only CocoaPods would need its platform integration restored.

The root [Flutter workflow](../.github/workflows/flutter.yml) is prepared to
run formatting, analysis, tests, the macOS journey, and Android/iOS build checks
on changes to `flutter/`. Its manual run also checks Linux and Windows desktop
builds. The workflow runs on relevant GitHub changes.
