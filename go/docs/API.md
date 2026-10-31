# Kankal API

This page describes the standalone Go API. Its machine-readable OpenAPI 3.1 contract is [`openapi.json`](./openapi.json), also served at `/openapi.json`. The interactive reference is at `/docs`. Local development listens at `http://127.0.0.1:8080` by default. Responses use JSON unless the status is `204`.

## Health checks

`GET /live` returns `200` with `{"status":"live"}`. `GET /ready` returns `200` with `{"status":"ready"}` when the service can accept requests. With PostgreSQL configured, readiness checks its connection and returns the fixed `503` error below if the database is unavailable. Both routes are public.

## Authentication

Every `/api/items` route requires `Authorization: Bearer <token>`. The service token comes from `KANKAL_BEARER_TOKEN`; it must contain at least 32 bytes and have no leading or trailing whitespace. Missing or invalid credentials return `401`:

```json
{"error":{"code":"unauthorized","message":"valid bearer token required"}}
```

This is one shared service credential. The API has no user identity or per-item ownership.

## Items

An item contains `id`, `title`, and `description`. The server generates the ID. `GET /api/items` returns items in creation order, and returns `[]` when there are none. There is no pagination. Items are durable across process restarts when `KANKAL_DATABASE_URL` selects PostgreSQL. Without it, items remain in memory and are lost when the process exits.

| Method and path | Behavior | Success |
| --- | --- | --- |
| `GET /api/items` | List all items | `200` array |
| `POST /api/items` | Create an item; includes a relative `Location` header | `201` item |
| `GET /api/items/{id}` | Read an item | `200` item |
| `PUT /api/items/{id}` | Replace its title and description | `200` item |
| `DELETE /api/items/{id}` | Delete an item | `204`, empty body |

Create and replace accept one JSON object. `title` is required, must not be blank, and may contain at most 200 Unicode characters. `description` is optional and may contain at most 2,000 Unicode characters; when omitted it is an empty string. Unknown fields, malformed JSON, and trailing JSON values are rejected. The request body limit is 1 MiB.

Errors use `{"error":{"code":"...","message":"..."}}`. Messages are fixed and do not include submitted values.

| Status | Code | Message | When |
| --- | --- | --- | --- |
| `400` | `invalid_json` | `request body must be a valid JSON object` or `request body must contain one JSON object` | Malformed JSON, unknown fields, or extra JSON values |
| `400` | `invalid_item` | `title is required and must be 1 to 200 characters; description must be at most 2000 characters` | Missing/blank/too-long title or too-long description |
| `401` | `unauthorized` | `valid bearer token required` | Missing or invalid bearer token |
| `404` | `not_found` | `item not found` | Requested item does not exist |
| `413` | `payload_too_large` | `request body exceeds 1 MiB` | Body exceeds the limit |
| `500` | `internal_error` | `an unexpected error occurred` | An unexpected internal failure |
| `503` | `service_unavailable` | `database unavailable` | Configured PostgreSQL becomes unavailable |

## Example

```sh
curl -H "Authorization: Bearer $KANKAL_BEARER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Buy tea","description":"Green tea"}' \
  http://127.0.0.1:8080/api/items
```
