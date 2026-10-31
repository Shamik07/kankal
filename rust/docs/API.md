# Kankal item gRPC contract

This document covers the original service-token API. For the user-facing API used by the web app, see [Workspace API](WORKSPACE.md).

The versioned [Protocol Buffers file](../proto/kankal/items/v1/items.proto) defines the wire contract. All item methods require `authorization: Bearer <OIDC service token>` metadata. The server verifies the RS256 signature against the configured JWKS, the exact issuer and audience, expiration, and the subject allowlist. Missing or invalid tokens return `UNAUTHENTICATED`; a valid token from a service outside the allowlist returns `PERMISSION_DENIED`.

| Method | Result |
| --- | --- |
| `ListItems` | All items in creation order; an empty list before any item is added |
| `CreateItem` | A new item with a server-assigned positive ID |
| `GetItem` | One item by ID |
| `UpdateItem` | The complete replacement title and description |
| `DeleteItem` | An empty response after removal |

The title must contain a non-whitespace character and be at most 200 Unicode characters. The description is optional and at most 2,000 Unicode characters. IDs must be positive. The store holds at most 1,000 items; deletion makes room for another item. Request messages are capped at 16 KiB. Calls have a 10-second server timeout; clients should set their own deadlines and handle cancellation. Changes are only in memory and are lost on restart.

| gRPC status | Meaning |
| --- | --- |
| `INVALID_ARGUMENT` | Invalid item fields or ID |
| `UNAUTHENTICATED` | Missing or invalid token |
| `PERMISSION_DENIED` | Valid token, service subject not allowed |
| `NOT_FOUND` | Item ID does not exist |
| `RESOURCE_EXHAUSTED` | Item capacity or ID space exhausted |
| `OUT_OF_RANGE` | Request exceeds the message limit |
| `UNAVAILABLE` | Identity keys cannot be refreshed or the server is stopping |
| `INTERNAL` | Item store cannot be accessed |

Error messages are fixed and never echo submitted values. All status codes follow the [gRPC status code guide](https://grpc.io/docs/guides/status-codes/). The public `grpc.health.v1.Health` service reports overall and item-service health. The public gRPC reflection v1 service exposes the `.proto` description to development tools. During shutdown, health changes to `NOT_SERVING` before the server stops accepting calls.

For compatibility, add fields with new field numbers. Reserve the number and name of a removed field. Keep changes to existing methods compatible within `v1`; use a new package version for breaking changes. Buf lint, format, and breaking-change checks enforce the contract in CI.
