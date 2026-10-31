# Kankal handoff: PostgreSQL starter next

> **Update, September 27, 2026:** The boundary proposed below was accepted and
> the Go item API now has optional PostgreSQL persistence. The remaining text
> records the earlier research handoff and is historical, not a current task
> list. See [go/README.md](go/README.md) and [go/docs/SCHEMA.md](go/docs/SCHEMA.md)
> for the implemented setup.
>
> The starter uses PostgreSQL 18.6 in Compose and prepared CI, pgx v5 in the
> API, and Goose SQL migrations. The existing in-memory mode and HTTP contract
> remain available. A PostgreSQL item survived a router/database-connection
> restart in the isolated journey test; CRUD, readiness failure, migration up,
> refusal to drop a nonempty table, and dump/restore were checked against a
> temporary local PostgreSQL 15.15 cluster. Go race tests, vet, formatting,
> OpenAPI lint, and Compose configuration passed. Docker's daemon remained
> unresponsive, so the PostgreSQL 18.6 image and remote CI have not run here.

## Goal

Build Kankal's next reusable starter around PostgreSQL, with a complete,
durable data journey and the same quality bar as the existing services: clear
ownership, safe migrations, isolated tests, explicit failures, useful
diagnostics, documentation, and prepared CI. **Settle the boundary before
scaffolding.** The owner has called this the "Postgres database starter" but
has not yet chosen between a standalone `postgres/` foundation, adding
persistence to the Go item API, or both. The prior conversation recommended
proving persistence through the Go item journey; that was advice, not an
approved design decision. Do not connect all starters to one database by
default.

## Current Progress

- Kankal is a collection of independent starters. Read the root
  [AGENTS.md](AGENTS.md) and [README.md](README.md) before work. The Flutter
  and web starters use in-memory mock APIs and are not connected to a backend.
- The [Go REST starter](go/README.md) uses Gin, a required shared bearer
  token, OpenAPI and Scalar, and a concurrency-safe in-memory item store. The
  [Rust gRPC starter](rust/README.md) uses Tonic, OIDC service tokens,
  Protocol Buffers, gRPC health and reflection, and a bounded in-memory item
  store. Neither has a database. Their HTTP and gRPC contracts are independent.
- The [FastAPI AI/ML starter](fastapi/README.md) serves ten offline, read-only
  demonstration journeys using bundled synthetic models. It has no database,
  uploads, or durable jobs. Its outputs are illustrative, not decision-grade.
- There is no PostgreSQL schema, migration, database Compose file, or
  application database connection in this workspace. Local `psql`,
  `postgres`, `initdb`, and `pg_ctl` are installed at PostgreSQL 15.15.
  Installed version is not a decision about the new starter's target version.
- Go, Rust, and FastAPI now have Dockerfiles. Go and Rust use multi-stage,
  non-root distroless runtimes; their READMEs explain runtime secrets and
  external health probes. The Go Linux ARM64 static binary cross-build passed
  at 13.2 MB. A stripped Rust macOS ARM64 release binary built at 8.2 MB;
  this is not a Linux image-size measurement. Go race tests and vet passed;
  Rust's eight isolated tests, Clippy, and formatting passed. Dockerfile
  static scans found no high or critical issues. The CI workflows are prepared
  to build, size-report, and scan the images.
- **Container builds and image scans are unverified.** Docker Desktop's local
  daemon did not respond; Colima is installed but has no instance. No Git
  repository is initialized, so prepared CI has not run remotely. The latest
  attempt to run Buf checks found that `buf` is not installed. No frontend
  integration, production identity provider, deployment certificate, or
  durable data path has been verified.
- Disk space is tight: about 21 GiB free and 98% used after Rust release
  builds. Check it before starting a new container VM, downloading images, or
  running large test suites.

## What Worked

- Ground decisions in the actual starter contracts and official, current
  documentation. Ask one focused question when a choice changes the public
  API, stored data, migration path, security, or deployment shape.
- Build a complete vertical slice with a failing observable test first, then
  make it pass. The Go `httptest` journey and Rust loopback gRPC journey are
  useful examples of isolated proof. For PostgreSQL, use a fresh test database
  or temporary cluster, not a shared or production service.
- Keep validation and authorization at the service boundary, database
  constraints in the schema, and transactions around multi-step changes.
  Use safe, fixed outcome logs that omit credentials, item contents, SQL
  parameter values, raw URLs, and exception messages.
- For container work, Docker's Go and Rust guides supported multi-stage
  builds and cache mounts. Distroless static fit Go; distroless base-nossl
  fit Rust's glibc and CA-certificate needs. A static Go cross-build and a
  stripped Rust release build gave useful size evidence without Docker.
- Home-directory caches were restricted in the sandbox. Task-specific caches
  under `/private/tmp` worked for Python and Go tools. Loopback tests needed
  sandbox escalation; the tests themselves used only local fixtures.

## What Didn't Work

- The previous handoff stayed focused on FastAPI after that starter was built.
  Check current source and docs rather than following stale next steps.
- Docker Desktop did not provide a working daemon even after opening it.
  Do not call an image verified because its Dockerfile passes static checks.
  Starting a new Colima VM without checking disk use would be risky here.
- An initial Rust Dockerfile dependency-fetch layer lacked package targets;
  `cargo fetch` cannot parse a manifest without `src` targets. It was removed;
  the build stage still uses BuildKit registry and target cache mounts.
- A normal Rust debug build previously exhausted disk. Incremental builds
  off and debug symbols disabled helped. The current release profile strips
  symbols and uses panic-abort for a smaller binary. Avoid unnecessary
  rebuilds of unchanged Rust code.
- An image build, a passing code test, and a static Dockerfile scan prove
  different things. The missing image build/runtime smoke and remote CI must
  remain explicitly unverified until they actually run.

## Next Steps

1. Read this handoff, root [AGENTS.md](AGENTS.md), and the relevant service
   README and API contract. Ask the owner which PostgreSQL starter boundary
   they want: standalone database foundation, Go item persistence, or both.
   Confirm the first stored-data journey, expected durability, and whether
   its existing public API must remain compatible. Do not create migrations
   before this decision.
2. Research supported PostgreSQL versions and the current official image,
   driver, migration tool, pooling, backup/restore, and security guidance.
   Choose a version intentionally, not merely because local Homebrew has 15.15.
   Decide data ownership, IDs, constraints, index strategy, transaction
   boundaries, and whether a connection pool belongs in the selected service.
3. Build one end-to-end persistent journey with a red-green cycle. If Go is
   selected, preserve its authentication and HTTP contract unless the owner
   explicitly changes them; replace only the in-memory ownership needed for
   persistence. Use additive, reviewable migrations with a safe rollback or
   forward-repair strategy. Never run migration tests against shared data.
4. Set up an isolated local PostgreSQL environment. A dedicated temporary
   cluster is feasible with installed `initdb` and `pg_ctl` if Docker remains
   unavailable; choose a task-specific data directory and port under
   `/private/tmp`. A Compose setup can follow the selected boundary, using the
   official PostgreSQL image, a durable local volume, health checks, and
   no committed secrets. Do not treat Compose as production backup or HA.
5. Prove migration up and failure behavior, CRUD persistence across a service
   restart, concurrency where relevant, and data isolation. Run focused
   service tests and required quality checks, plus a real isolated journey.
   Add a prepared CI gate, update the actual API/schema documentation and root
   README, and report any Docker, backup/restore, or remote-CI check not run.

## Prompt for the next conversation

> Read `/Users/shamikchodankar/Work/Kankal/HANDOFF.md` and
> `/Users/shamikchodankar/Work/Kankal/AGENTS.md`. We are building Kankal's next
> reusable PostgreSQL starter. First help me settle whether it should be a
> standalone database foundation, persistence for the existing Go item API,
> or both. Use the current code and official PostgreSQL guidance to choose a
> version and a small durable journey. Then implement the agreed scope with
> safe migrations, isolated red-green tests, clear API and schema docs,
> backup/restore guidance, and prepared CI. Do not connect the unrelated
> starters automatically or use any shared database for tests.
