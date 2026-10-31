# Kankal Rust gRPC starter

A Rust gRPC service with a PostgreSQL-backed user workspace and a separate in-memory service-token item example. It uses Tonic, Protocol Buffers, OIDC service tokens, structured outcome logs, standard gRPC health and reflection services, and optional OpenTelemetry export. The workspace API connects to the web starter. Flutter and Go remain independent.

The service-token item example remains in memory. Workspace items and sessions use PostgreSQL. See [Workspace API](docs/WORKSPACE.md) for behavior and limits.

## Requirements

Rust 1.95 or newer. Cargo downloads the locked crate versions. The build uses a vendored Protocol Buffers compiler, so a separate `protoc` install is unnecessary.

An OIDC provider must issue RS256 service tokens with an `iss`, `aud`, `sub`, and `exp` claim and publish its public keys as a JWKS document. Configure the allowed service subjects explicitly. No signing key or access token belongs in this repository.

## Run

From `rust/`, set:

```sh
export KANKAL_OIDC_ISSUER='https://identity.example.com/'
export KANKAL_OIDC_AUDIENCE='kankal-items'
export KANKAL_OIDC_JWKS_URL='https://identity.example.com/.well-known/jwks.json'
export KANKAL_ALLOWED_SUBJECTS='service-a,service-b'
cargo run --locked --bin kankal-grpc
```

The default address is `127.0.0.1:50051`. For a non-loopback address, set `KANKAL_ADDR` and both `KANKAL_TLS_CERT_PATH` and `KANKAL_TLS_KEY_PATH`; startup rejects a public plaintext listener. These paths refer to operator-managed files, never checked-in material. The service checks the JWKS document at startup. It refreshes the key cache every 60 seconds, treats keys as valid for five minutes, and reports not serving when the cache expires without a successful refresh. OIDC and JWKS URLs must use HTTPS except on loopback, which supports isolated local tests. On SIGINT or SIGTERM, the service marks health as not serving and allows up to ten seconds for active calls to finish.

To export traces and the `grpc.server.call.duration` metric to an OpenTelemetry collector, set `OTEL_EXPORTER_OTLP_ENDPOINT` to its OTLP gRPC endpoint. Without it, the service writes JSON logs to standard output. Logs and telemetry contain fixed method names, status codes, and outcomes. They do not contain tokens, item fields, request bodies, raw URLs, or raw errors.

## Contract

[`proto/kankal/items/v1/items.proto`](proto/kankal/items/v1/items.proto) is the source of truth. The gRPC reflection service lets tools such as `grpcurl` discover it. See [API.md](docs/API.md) for method, authentication, and error details. This pure gRPC starter has no OpenAPI or Scalar page.

For a local plaintext listener, after obtaining a token from your configured identity provider:

```sh
grpcurl -plaintext -H "authorization: Bearer $TOKEN" \
  -d '{"title":"Buy tea","description":"Green tea"}' \
  127.0.0.1:50051 kankal.items.v1.ItemsService/CreateItem
```

## Checks

```sh
cargo test --locked
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
buf lint
buf format --diff --exit-code
```

The isolated gRPC journey uses a loopback server and a test-generated signing key. A local collector test confirms trace and duration export on Unix. These tests never contact a shared identity provider or database. The CI workflow runs the checks and compares `.proto` changes with the pull request base branch.

## Container

The multi-stage [Dockerfile](Dockerfile) builds a stripped release binary and
copies it into a non-root distroless image. The runtime has glibc and public CA
certificates for HTTPS identity-key requests, but no shell, package manager, or
OpenSSL library. Build from `rust/`:

```sh
docker build -t kankal-grpc:local .
```

For a non-loopback listener, this service **requires its own TLS certificate
and key**. Mount operator-managed files read-only, make them readable by the
container's non-root user, and set `KANKAL_TLS_CERT_PATH` and
`KANKAL_TLS_KEY_PATH` to their container paths. Also supply the four required
OIDC settings shown above. For example, after exporting those settings on the
host and selecting readable certificate and key files:

```sh
docker run --rm --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  -p 127.0.0.1:50051:50051 \
  --mount type=bind,src=/path/to/server.crt,dst=/run/tls/server.crt,readonly \
  --mount type=bind,src=/path/to/server.key,dst=/run/tls/server.key,readonly \
  -e KANKAL_OIDC_ISSUER -e KANKAL_OIDC_AUDIENCE \
  -e KANKAL_OIDC_JWKS_URL -e KANKAL_ALLOWED_SUBJECTS \
  -e KANKAL_TLS_CERT_PATH=/run/tls/server.crt \
  -e KANKAL_TLS_KEY_PATH=/run/tls/server.key kankal-grpc:local
```

The container listens on port 50051; the sample port mapping stays on host
loopback. Provide certificates and OIDC settings through deployment-managed
secrets and configuration. Probe the public `grpc.health.v1.Health` service from
the orchestrator with TLS verification; the runtime has no gRPC client for an
in-container `HEALTHCHECK`. Give the process at least 10 seconds to finish on
SIGTERM. Items remain in memory and are not shared across replicas.

For example, from the host with a trusted CA certificate and a server
certificate valid for `127.0.0.1`, use:

```sh
grpcurl -cacert /path/to/ca.crt \
  -d '{"service":"kankal.items.v1.ItemsService"}' \
  127.0.0.1:50051 grpc.health.v1.Health/Check
```

CI builds and scans the runtime image and reports its size. Deploy an immutable
image digest after those checks pass.

## Run the web workspace

Create an empty local PostgreSQL database, then set `KANKAL_DATABASE_URL` to its connection URL. Run `cargo run --bin create-workspace-account -- you@example.com` and enter a password at the hidden prompts. Run `cargo run --bin kankal-grpc`; it applies the versioned migrations in `migrations/` and serves the workspace API on `127.0.0.1:50051`. With no OIDC issuer configured, the workspace runs without the service-token example. Supplying its existing OIDC settings also enables that example. See [the web README](../web/README.md) for the browser setup.

For browser tests, create a fresh **dedicated test database**. Set `KANKAL_TEST_DATABASE_URL` to it and run `cargo test --locked --test workspace_journey -- --ignored`; this migrates it and creates test accounts and data. Start the server with `KANKAL_DATABASE_URL` pointing to that same test database, then run `bun run test:e2e:check` from `web/`. Do not use shared or production data. The checked-in workflow uses a disposable PostgreSQL service.

## Rust development references

Use [Let's Get Rusty](https://learn.letsgetrusty.com/) for Rust learning and design references, [Beautiful Rust](https://github.com/morganlinton/BeautifulRust) for idiomatic coding guidance, and the [Google Rust Style Guide](https://google.github.io/styleguide/rustguide.html) in context. Check current official crate documentation for version-specific behavior. Keep application code direct and favor the project's existing checks over additional test layers.
