# Kankal Flutter — Project CLAUDE.md

## Stack

- **Flutter SDK**: `^3.7.2` — always use `fvm flutter`, never bare `flutter`
- **State management**: `stacked` v3.4.4 (NOT Riverpod — global rules mention Riverpod but this project uses Stacked)
- **FVM**: `.fvmrc` present — SDK version pinned

## Stacked Conventions

Stacked follows MVVM:
- `ViewModelBuilder` / `StackedView` widgets observe ViewModels
- ViewModels extend `BaseViewModel` (or `FutureViewModel`, `StreamViewModel`)
- Services are registered in `app/app.dart` via `locator` (get_it under the hood)
- No business logic in `build()` — only layout composition

**Key patterns**:
```dart
// Register service
@injectable
class MyService {}

// ViewModel
class MyViewModel extends BaseViewModel {
  final _myService = locator<MyService>();
}

// View
class MyView extends StackedView<MyViewModel> {
  @override
  Widget builder(BuildContext context, MyViewModel viewModel, Widget? child) { ... }
  
  @override
  MyViewModel viewModelBuilder(BuildContext context) => MyViewModel();
}
```

## Test Commands

```bash
fvm flutter test          # unit + widget tests
fvm flutter analyze       # must be clean before commit
```

Zero warnings policy — `flutter analyze` must be clean.

## Notes

- `lib/` is currently minimal (only `main.dart`) — follow Stacked's app structure as the project grows
- Assets must be declared in `pubspec.yaml` before use
- No `Navigator.push` — route navigation goes through Stacked's router or named routes only
