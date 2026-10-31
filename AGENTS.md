# Kankal project guide

## Code style

- Follow [STYLE.md](STYLE.md) for language references, adopted rules, project
  exceptions, and existing style checks. Apply it to new and changed code.
- Project requirements and checked-in tool settings take precedence over
  external guides. Do not make unrelated style rewrites.

## Layout and current behavior

- The Flutter starter lives in `flutter/`. Run Flutter and Dart commands there.
- `flutter/lib/` contains a Stacked app with mock email/password and email-code
  sign-in, protected named routes, and an in-memory item CRUD example.
- `flutter/packages/kankal_ui/` is the local presentation package with a
  runnable example app. Keep business logic and navigation in the main app.
- `flutter/test/` holds focused API and widget tests;
  `flutter/integration_test/` holds the signed-in item journey.
- The root `test/` directory is not the application's test directory.
- Platform runners exist for Android, iOS, macOS, Windows, Linux, and web.

## Vite web starter

- The Vite, React, and TypeScript starter lives in `web/`. Run Bun commands there.
- `web/src/api/` contains the workspace gRPC-Web adapter and mock APIs used in isolated tests; `web/src/app/` owns services and protected routes; `web/src/features/` owns screen behavior. Reusable shadcn/ui components and content states live in `web/src/components/`.
- `/ui` is a public, runnable component showcase. The web workspace uses the Rust gRPC-Web API and PostgreSQL-backed sessions and items.
- Read `web/PRODUCT.md`, `web/DESIGN.md`, and `rust/docs/WORKSPACE.md` before changing web behavior or UI. The palette is a replaceable demo style.
- Use `bun install --frozen-lockfile`, `bun run test`, `bun run lint`, `bun run typecheck`, `bun run build`, and `bun run test:e2e:check` from `web/` as appropriate. The Playwright journey and accessibility check use local Chrome at desktop, phone, and 320px widths.
- `.github/workflows/web.yml` runs the web checks on relevant changes.

## Go API starter

- The standalone Go service lives in `go/`. Run Go commands there and read its
  README and API contract before changing its behavior. The machine-readable
  OpenAPI contract is `go/docs/openapi.json`, served at `/openapi.json`, with a
  Scalar reference at `/docs`. Update and verify the contract when routes or
  response behavior change.
- It uses Gin, a required configured bearer token, and an in-memory item store
  by default. `KANKAL_DATABASE_URL` enables PostgreSQL 18.6 persistence with
  versioned SQL migrations in `go/migrations/`. It has no user account system.
  Its HTTP contract is independent of the Flutter and web APIs;
  neither frontend is integrated with it.
- Keep request handling and validation in the HTTP boundary, and keep item
  storage safe for concurrent requests. Never log bearer tokens, item content,
  request bodies, raw URLs, or raw error messages. Log fixed outcomes only.
- Use a red-green test cycle for behavior changes. The isolated HTTP journey
  uses `httptest`. PostgreSQL tests require a fresh, migrated test database via
  `KANKAL_TEST_DATABASE_URL`; never point them at shared or production data.
- Run `go test -race -count=1 ./...`, `go vet ./...`, and check `gofmt` from
  `go/`. `.github/workflows/go.yml` runs these checks on relevant changes.

## Rust gRPC starter

- The standalone Rust service lives in `rust/`. Run Cargo and Buf commands there.
  Read `rust/README.md` and `rust/docs/API.md` before changing its behavior.
- `rust/proto/kankal/items/v1/items.proto` is the versioned gRPC contract. The
  service uses Tonic, OIDC RS256 service tokens, standard gRPC health and
  reflection, and a concurrency-safe in-memory item store capped at 1,000 items.
  A separate workspace gRPC API uses PostgreSQL and connects to the web starter.
- Keep item validation and token checks at the gRPC boundary. Never log tokens,
  item content, request bodies, raw URLs, or raw errors. Logs and telemetry use
  fixed method names, statuses, and outcomes.
- Use red-green tests for changed behavior. The isolated gRPC journey starts a
  loopback service and generates its signing key in memory; it must not contact
  an external identity provider or shared data service. The workspace journey
  requires a fresh dedicated PostgreSQL test database; see `rust/README.md`.
- Run `cargo test --locked`, `cargo fmt --check`,
  `cargo clippy --locked --all-targets -- -D warnings`, `buf lint`, and
  `buf format --diff --exit-code` from `rust/`. `.github/workflows/rust.yml`
  runs these checks and Protocol Buffers compatibility checks.

## Toolchain and conventions

- Use `fvm flutter` and `fvm dart` with `flutter/.fvmrc`.
- The FVM configuration pins Flutter `3.44.6`.
- `pubspec.yaml` requires Dart `^3.7.2`; this is not a Flutter SDK version.
- Read `flutter/CLAUDE.md` for existing project conventions; leave that file
  intact. Its SDK version and starter-structure notes predate this Flutter
  starter, so use the current facts in this guide and `flutter/README.md`.
- Stacked is the chosen state management library. Keep business logic in
  ViewModels when adding features, and use Stacked routing or named routes.
- The starter uses Stacked ViewModels and named routes. It does not use a service
  locator or generated routing; add those only when a feature needs them.
- For a screen with genuinely different compact and wide compositions, keep
  one primary view and one ViewModel. Give each layout a focused widget while
  sharing form fields and state. Choose by available width, not repeated OS
  branches; do not create unused layouts for every device type.
- `AuthApi` and `ItemsApi` have in-memory mock implementations. No real backend,
  persistent session, or remote telemetry is configured.
- Use `Diagnostics.record` for fixed outcome events and `recordError` for
  unexpected errors. Structured diagnostics must not log credentials, email
  addresses, OTP codes, item contents, request bodies, or raw exception
  messages. Flutter's normal debug error reporter is still active, so never
  put sensitive values in exception messages either.
- Follow `flutter/analysis_options.yaml`, which includes Flutter's recommended
  lints. Declare new assets in `flutter/pubspec.yaml`.
- Avoid editing generated output in `build/`, `.dart_tool/`, or platform ephemeral
  directories. Keep unrelated platform configuration unchanged.

## Development method

- Use test-driven development for new behavior and bug fixes: write one test for
  an observable behavior, confirm it fails for the intended reason, implement
  the smallest working change, then refactor with the test green. Repeat for the
  next behavior instead of writing a large test suite up front.
- Keep the strongest test at the owning boundary. Add another layer only for a
  distinct risk such as route access, persistence, or a complete user journey.

## Verification

Run from `flutter/`, choosing checks appropriate to the changed behavior:

```sh
fvm flutter test test/widget_test.dart
fvm flutter test test/core/auth/mock_auth_api_test.dart test/core/items/mock_items_api_test.dart
fvm flutter test test/core/diagnostics/diagnostics_test.dart
fvm flutter test test/features/items/items_view_model_test.dart
fvm flutter test test/features/items/item_editor_view_model_test.dart
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fvm flutter test integration_test/mock_item_journey_test.dart -d macos
fvm flutter analyze
fvm dart format --output=none --set-exit-if-changed lib test integration_test
```

Use focused tests for new features. Analyzer output must be clean before a commit.
For UI changes, inspect the running application at relevant sizes and states;
passing tests alone do not establish visual quality. Follow the user's design
rules and use Impeccable for requested UI work. Load its context from `flutter/`
so it reads `flutter/PRODUCT.md` and the Flutter-specific design rules. Check
iOS and Android UI on a simulator or device before claiming those platforms'
visual behavior is verified; a browser preview is only supplementary.

Documentation-only changes do not require an application build or test run.
Never report a check as passed unless it actually ran successfully.
