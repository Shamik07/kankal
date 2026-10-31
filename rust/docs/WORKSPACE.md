# Workspace API

`proto/kankal/workspace/v1/workspace.proto` defines the user-facing gRPC API. The browser uses gRPC-Web over the same origin; native clients may use gRPC. This API is separate from the existing service-token item API in `API.md`.

An operator creates accounts with `create-workspace-account`. Sign-in accepts an email and password, returns the user identity, and issues an HTTP-only, SameSite=Strict session cookie. The server stores only a SHA-256 hash of the random session token. Sessions expire after seven days; sign-out revokes the current token. PostgreSQL stores Argon2id password hashes and item data. User ID is derived from the session, never accepted from the browser.

Item calls validate their input and filter every query by the signed-in user. A missing or expired session returns `UNAUTHENTICATED`; access to another user's item returns `NOT_FOUND`. Invalid fields return `INVALID_ARGUMENT`; database failures return a fixed `UNAVAILABLE` error. Each server process limits sign-in to 20 attempts per minute across all emails and five attempts per email in 15 minutes. These limits reset on restart and are not shared between instances; they can temporarily block other users during a burst.

The workspace health check and overall readiness become `NOT_SERVING` when PostgreSQL cannot be reached and return to `SERVING` after it recovers. Health checks run approximately every two seconds with a one-second database timeout.

The server accepts gRPC-Web requests but does not enable cross-origin browser access. Serve the app and API on the same origin. TLS is required for non-loopback listeners. When TLS ends at a reverse proxy on a loopback listener, set `KANKAL_SECURE_COOKIES=true` and configure the proxy to require HTTPS. Account recovery, email verification, distributed rate limiting, and production deployment are not included; add what the product needs before onboarding customers.
