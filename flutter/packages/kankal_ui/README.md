# kankal_ui

A small Material 3 presentation package for Kankal. It contains no routing,
application state, authentication, service, or network behavior.

```dart
import 'package:kankal_ui/kankal_ui.dart';

MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  home: const MyScreen(),
)
```

Use `AppButton` for filled or outlined actions, `AppTextField` inside a normal
`Form`, and `AppLoadingIndicator`, `AppEmptyState`, or `AppErrorState` for
content regions. The controls keep Material keyboard, focus, validation, and
text scaling behavior.

Run the example app in Chrome from this directory with:

```sh
cd example
fvm flutter run -d chrome -t lib/main.dart
```

The example includes a web runner, so `fvm flutter build web` also works from
`example/`.

## Widgetbook

The example also has a separate Widgetbook entry point for inspecting each
component state in isolation. From `example/`, run:

```sh
fvm flutter pub get
fvm flutter run -d chrome -t lib/widgetbook.dart
```

Use its theme, viewport, and text-size controls to check buttons, text fields,
content states, and the confirmation dialog. Add a use case in `example/lib/widgetbook.dart`
when a shared component gains a meaningful state. The original `lib/main.dart`
showcase remains available. Build Widgetbook with
`fvm flutter build web -t lib/widgetbook.dart`.
