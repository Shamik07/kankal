# Kankal

Kankal is a collection of reusable project starters. Each starter keeps its
application, shared packages, tests, and setup notes together so a new project
can begin from a working example.

The [Flutter starter](flutter/README.md) and [Vite web starter](web/README.md)
provide platform-specific UI foundations and focused checks. The web starter
connects to the Rust workspace API and PostgreSQL; Flutter remains a standalone
mock demo.

Shared UI can be inspected in the web starter's Storybook and the Flutter UI
package's Widgetbook. Both are local development tools. The web workspace
uses gRPC-Web to reach the Rust backend.

The [Go API starter](go/README.md) is a separate, runnable service with its own
HTTP contract and interactive API reference. It runs with an in-memory item
store by default and has an optional PostgreSQL 18.6 mode with versioned SQL
migrations and durable items. It is not connected to either frontend.

The [Rust gRPC starter](rust/README.md) provides a PostgreSQL-backed workspace API for the web starter, plus a
separate service-token gRPC example with an in-memory item store.

The [FastAPI AI/ML starter](fastapi/README.md) is a separate, offline service
with ten read-only demonstration journeys, OIDC service authentication,
OpenAPI and Scalar documentation, and synthetic bundled models. It is not
connected to the other starters.
