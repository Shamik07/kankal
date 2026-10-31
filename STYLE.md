# Kankal code style

This is the local source for adopted style rules and project exceptions. The
official guides linked below provide detail. Keep these local rules available
in the repository instead of maintaining full copies of the external guides.

## Scope and precedence

- Project requirements in [AGENTS.md](AGENTS.md), API contracts, and each
  workspace's `PRODUCT.md` and `DESIGN.md` take precedence over style advice.
- Checked-in formatter, linter, and compiler settings control automated checks.
  The rules below take precedence over external style guides.
- Rules recorded here or in project requirements are required. Other external
  recommendations are advisory; linking a guide does not adopt every rule in it.
- Apply this guidance to new and changed code. Keep unrelated code unchanged;
  do not make broad style rewrites or manually edit generated code.
- External guide updates do not automatically change project policy or tooling.
  Record deliberate changes and exceptions here.
- These rules cover code. Visual design remains in the workspace design files.

## Dart and Flutter

Use [Effective Dart](https://dart.dev/effective-dart) as the main reference for
naming, documentation, language use, and API design. Consult its `DO`, `PREFER`,
and `CONSIDER` guidance when local rules do not cover a decision.

Let `dart format` control formatting and keep the existing `flutter_lints`
configuration. Keep Stacked, ViewModels, named routes, and the shared UI package
boundaries described in `AGENTS.md`.

From `flutter/`:

```sh
fvm dart format --output=none --set-exit-if-changed lib test integration_test packages/kankal_ui/lib packages/kankal_ui/test packages/kankal_ui/example/lib
fvm flutter analyze
fvm dart analyze packages/kankal_ui
```

## Go

Use the [Google Go guide](https://google.github.io/styleguide/go/) for its core
principles: clarity, simplicity, concise code, maintainability, and consistency.
Use descriptive names and comments that explain reasons. Consult its decisions
and best practices when relevant; they do not require restructuring working code.
Let `gofmt` control formatting.

From `go/`:

```sh
gofmt_output=$(gofmt -l .) && test -z "$gofmt_output"
go vet ./...
```

## Python

Use the [Google Python guide](https://google.github.io/styleguide/pyguide.html)
for naming, useful docstrings, type annotations, and explicit error handling.
Avoid mutable default arguments and broad exception handling that hides failures.

Keep [the existing configuration](fastapi/pyproject.toml): Ruff, strict mypy,
and 88-character lines. Do not add Pylint or change to Google's 80-character
limit for style compliance. Direct imports of FastAPI and Pydantic classes and
functions remain valid; a module-only import rule is not adopted.

From `fastapi/`:

```sh
uv run --locked ruff format --check src tests scripts
uv run --locked ruff check src tests scripts
uv run --locked mypy
```

## TypeScript

Use the [Google TypeScript guide](https://google.github.io/styleguide/tsguide.html)
as a reference for clear names, `const` by default, and explicit error handling.
Keep React/Vite conventions, strict TypeScript, and Oxlint. Use type-only imports
where required by the current compiler settings.

Keep existing file formatting and export conventions, including default exports
and Storybook metadata. There is no configured web formatter;
this policy does not add one or require Google's punctuation and import layout.

From `web/`:

```sh
bun run lint
bun run typecheck
```

## HTML and CSS

Use the [Google HTML/CSS guide](https://google.github.io/styleguide/htmlcssguide.html)
for meaningful HTML elements, accessible alternatives for media, and readable CSS.
Keep valid JSX with explicit closing or self-closing tags. Do not apply the raw
HTML option to omit tags to JSX.

Keep Tailwind utilities, local shadcn/ui components, and design tokens as defined
in [the web design rules](web/DESIGN.md). Do not rename utility classes or reorganize
styles solely to match Google's CSS naming or declaration order. Retain the
project's keyboard, focus, and accessibility checks for affected UI behavior.

## Rust

Use the [Google Rust guide](https://google.github.io/styleguide/rustguide.html)
in context, as described in [the Rust README](rust/README.md#rust-development-references).
Prefer clear ownership, borrowing when practical, and `Result` for recoverable
errors. Keep application code direct; add traits and generic APIs when needed.

Keep Cargo's module layout, the existing Tokio/Tonic async runtime, and `Arc`
where shared service state needs it. Chromium and Fuchsia-specific build,
concurrency, and layout rules do not apply. Keep the current toolchain's `rustfmt`
and Clippy settings; do not add unstable formatting options for compliance.

From `rust/`:

```sh
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
buf lint
buf format --diff --exit-code
```

The commands above cover style and static checks. Use each workspace's existing
verification instructions for behavior changes, builds, and tests.
