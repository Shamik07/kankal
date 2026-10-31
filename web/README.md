# Kankal Web

The Vite, React, and TypeScript app connects to Kankal's Rust workspace API over gRPC-Web. PostgreSQL stores users, sessions, and items. The local Vite server proxies workspace requests to `127.0.0.1:50051`.

## Run locally

1. Start PostgreSQL and create an empty local database named `kankal_workspace` with your usual database tools. Use a dedicated database; startup applies Rust's versioned migrations.
2. From `rust/`, set `KANKAL_DATABASE_URL` to that database connection URL. Run `cargo run --bin create-workspace-account -- you@example.com` and enter a password of at least 12 characters at the prompts. The password is not passed as a command argument.
3. In the same environment, run `cargo run --bin kankal-grpc`. The workspace API listens on loopback port 50051 by default. The existing service-token API is available when its OIDC settings are also configured; see the Rust README.
4. From `web/`, run `bun install --frozen-lockfile` and `bun run dev`. Open the printed local URL and sign in with the account you created.

Items and sessions survive reloads and server restarts. Sessions expire after seven days and sign-out revokes the current session. Accounts are created by the operator; registration and password recovery are not included.

## Use for a new product

Copy the web and Rust directories into the new project. Rename the package, title, and visible labels, then update `PRODUCT.md` and `DESIGN.md`. Replace sample items with product data and update the workspace protobuf contract, generated web client, tests, and migrations together. Regenerate the web client from `web/` with `protoc -I ../rust/proto --plugin=protoc-gen-es=./node_modules/.bin/protoc-gen-es --es_out=src/api/gen --es_opt=target=ts ../rust/proto/kankal/workspace/v1/workspace.proto` using an installed Protocol Buffers compiler.

For a deployed product, serve the web app and gRPC-Web endpoint under the same HTTPS origin. Configure the reverse proxy to forward `/kankal.workspace.v1.WorkspaceService/` to Rust, set `KANKAL_SECURE_COOKIES=true` behind a TLS proxy, use a protected PostgreSQL connection, and provide account recovery before onboarding users. The Vite proxy is for local development only. See the Rust README for the current limits.

## Checks

Run `bun run test`, `bun run lint`, `bun run typecheck`, `bun run build`, and `bun run build:storybook` from `web/`. Run `bun run test:e2e:check` only with the Rust service running against an **isolated test database** seeded by the Rust workspace journey test; see `rust/README.md`. The browser checks use local Chrome at desktop, phone, and 320px widths. Never point these tests at user or production data.

Run `bun run storybook` for the component workbench. `/ui` is the in-app component showcase.
