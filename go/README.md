# Kankal Go API

A small standalone HTTP API for items. It uses Gin and one configured bearer token. By default, items live in memory and reset when the process stops. Set `KANKAL_DATABASE_URL` to use PostgreSQL for durable items. There are no user accounts or frontend connections in this starter.

## Requirements

Go 1.26 or newer. The module uses Go 1.26 and Gin v1.12.0. Gin's module requires Go 1.25, so it works with the installed Go 1.26.3 toolchain.
The [Go release history](https://go.dev/doc/devel/release) lists 1.27.1 as
current and 1.26.8 as the patched 1.26 release. CI uses 1.26.8.
[Gin's releases](https://github.com/gin-gonic/gin/releases) list v1.12.0 as
the latest stable version. HTTP journey tests use Go's
[`httptest`](https://pkg.go.dev/net/http/httptest) package.
The optional OpenAPI lint command uses Node 22 and a pinned Redocly CLI.
The PostgreSQL path uses pgx v5 and versioned SQL migrations run by Goose v3.24.0. Use PostgreSQL 18.6 for the starter database.

## Run

```sh
cd go
export KANKAL_BEARER_TOKEN="$(openssl rand -hex 32)"
export KANKAL_ADDR='127.0.0.1:8080' # optional; defaults to loopback port 8080
go run .
```

The bearer token is required, must contain at least 32 bytes, and cannot begin or end with whitespace. Keep it private and pass it as `Authorization: Bearer <token>` on item requests. The server handles SIGINT and SIGTERM with a 10-second graceful shutdown period.

## Durable PostgreSQL mode

The local Compose file runs the official PostgreSQL 18.6 image. It requires a password from your shell, keeps the database in a named volume, and binds its port to host loopback only. PostgreSQL 18 stores its data under `/var/lib/postgresql`, which is why the volume uses that path. Keep several gigabytes of free disk space before pulling the image.

```sh
cd go
export KANKAL_LOCAL_DB_PASSWORD="$(openssl rand -hex 24)"
docker compose up -d postgres
export PGPASSWORD="$KANKAL_LOCAL_DB_PASSWORD"
export KANKAL_DATABASE_URL='postgres://kankal@127.0.0.1:5432/kankal?sslmode=disable'
go install github.com/pressly/goose/v3/cmd/goose@v3.24.0
goose -dir migrations postgres "$KANKAL_DATABASE_URL" up
export KANKAL_BEARER_TOKEN="$(openssl rand -hex 32)"
go run .
```

The migration command runs before the API starts. The API refuses to start when PostgreSQL is unreachable or the `items` table is missing. `/ready` returns `503` if an established database connection becomes unavailable. Item requests then return a fixed `503` response without exposing database errors. The liveness route remains process-only.

The Compose password and database are for local development. For production, supply runtime credentials through a secret manager, use a restricted application role separate from the migration role, and require verified TLS for remote database connections. Avoid putting a password in a URL passed as a command argument because process listings can reveal it. Changing the Compose password environment variable after the volume is initialized does not rotate the stored database password.

See [schema and migration notes](docs/SCHEMA.md) for the data contract and rollback rule. The Go API is still independent of the Flutter, web, Rust, and FastAPI starters.

`GET /live` and `GET /ready` are public health checks. Item routes require the configured token. See [docs/API.md](docs/API.md) for request and response details.

Open [http://127.0.0.1:8080/docs](http://127.0.0.1:8080/docs) for the
interactive API reference. The service also publishes its OpenAPI 3.1 contract
at `/openapi.json`. The reference uses a pinned Scalar browser script from
jsDelivr, so the interactive page needs internet access; the OpenAPI document
remains available without it. Update `docs/openapi.json` with any HTTP contract
change and verify the served page and journey together.

The service emits structured outcome logs containing only the HTTP method and status code. It does not log request paths, query strings, bodies, item contents, token values, database URLs, SQL values, or raw errors. In-memory mode is intended for contract exploration. PostgreSQL mode keeps items across process restarts and can be used by multiple API instances against the same database.

## Backup and restore

A named volume preserves local data across container restarts, but it is not a backup. Make a custom-format dump and restore it into a **new** database to test recovery:

```sh
pg_dump -Fc -f kankal.dump "$KANKAL_DATABASE_URL"
createdb -h 127.0.0.1 -U kankal kankal_restore
pg_restore --no-owner --no-acl -d 'postgres://kankal@127.0.0.1:5432/kankal_restore?sslmode=disable' kankal.dump
psql 'postgres://kankal@127.0.0.1:5432/kankal_restore?sslmode=disable' -c 'SELECT count(*) FROM items'
```

Keep backups outside the database volume and protect them as user data. For production recovery objectives, arrange automated backups, retention, and point-in-time recovery with the database operator, then rehearse restores. A dump alone cannot recover changes made after it completed.

## Checks

```sh
go test -race ./...
go vet ./...
gofmt_output=$(gofmt -l .) && test -z "$gofmt_output"
npx --yes @redocly/cli@2.54.3 lint docs/openapi.json
```

The PostgreSQL journey test runs only when `KANKAL_TEST_DATABASE_URL` names a **dedicated, already migrated test database**. Never point it at shared or production data. CI starts a fresh PostgreSQL 18.6 service, applies the migrations, and sets this variable. Locally, create a disposable database and run `goose -dir migrations postgres "$KANKAL_TEST_DATABASE_URL" up` before `go test -race -count=1 ./...`. Check the test output for `TestPostgresItemSurvivesRouterRestart`; a skipped test does not verify persistence.

The OpenAPI linter currently passes with three advisory warnings: Kankal has
no declared license, and the two fixed public health routes have no 4xx
responses to document.

## Container

The multi-stage [Dockerfile](Dockerfile) builds a static Go binary and copies it
into a non-root distroless image. It does not include a shell or build tools.
Build and run it from `go/`:

```sh
docker build -t kankal-go:local .
docker run --rm --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  -p 127.0.0.1:8080:8080 -e KANKAL_BEARER_TOKEN kankal-go:local
```

Set `KANKAL_BEARER_TOKEN` in the host environment before running this command.
The container listens on port 8080; the sample port mapping stays on host
loopback. Supply the token through your deployment secret manager in a real
environment. Do not put it in the image or a Compose file. Probe `/live` and
`/ready` from the host or orchestrator. The distroless image has no HTTP client
for an in-container `HEALTHCHECK`. Give the process at least 10 seconds to
finish on SIGTERM. Without `KANKAL_DATABASE_URL`, replicas do not share items
and restarts erase them. Supply a database connection and credential through
your deployment secret manager for durable mode; apply migrations first.

From another terminal, check readiness with
`curl -fsS http://127.0.0.1:8080/ready`. CI builds and scans the runtime image and reports
its size. Deploy an immutable image digest after those checks pass.
