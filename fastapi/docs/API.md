# API contract

The service uses JSON and publishes OpenAPI at `/openapi.json`; `/docs` is its Scalar reference. All `POST /v1/...` calls require `Authorization: Bearer <OIDC service token>`. The token must be RS256 signed and have the configured issuer, audience, allowed subject, and unexpired `exp` claim. Health and documentation routes do not require the token, so restrict documentation at the ingress if it should not be visible to anonymous network clients.

| Journey | Route | Input | Output |
| --- | --- | --- | --- |
| Passage search | `/v1/search` | `query`, `limit` | ranked document IDs, passage text, scores |
| Text tagging | `/v1/text/tags` | `text` | category, score |
| Keyphrases | `/v1/text/keyphrases` | `text`, `limit` | ranked phrases and scores |
| Topic grouping | `/v1/text/topics` | `text` | group ID, example topic |
| Duplicate tickets | `/v1/text/duplicates` | `text`, `limit` | similar ticket IDs and scores |
| Recommendations | `/v1/recommendations` | bundled `item_id`, `limit` | similar item IDs and scores |
| Anomaly detection | `/v1/anomalies` | `temperature`, `vibration` | anomaly flag and signed score |
| Risk scoring | `/v1/risks` | machine `age`, `temperature` | probability and flag |
| Numeric prediction | `/v1/predictions` | `quantity`, `grade` | estimated value |
| Forecasting | `/v1/forecasts` | bundled `series_id`, `horizon` | predicted values |

Limits are defined in the OpenAPI request schemas. `limit` ranges from 1 to 5 for search and recommendations, and 1 to 10 for keyphrases and duplicates. Forecast horizon ranges from 1 to 7. Unknown catalog or series IDs return `404`. A match list can be empty. Text tagging and topic grouping return `unknown` when no terms are in their trained vocabulary. Scores are model-specific; do not compare them across journeys. Responses carry `X-Request-ID`; routed `/v1` responses also carry `X-Model-Version`. A body rejected before routing with `413` has no model version.

Errors use fixed JSON details. Missing or invalid tokens return `401`, a valid token from a disallowed subject returns `403`, bodies over 16 KiB return `413`, invalid fields return `422` with `{"detail":"Invalid request"}`, and unavailable identity keys or inference capacity return `503`. Unexpected failures return a generic `500` and never echo submitted content. Invalid or missing model artifacts prevent startup instead of serving requests. A caller should retry `503` with backoff; retrying invalid input or credentials will not help.

All bundled data is synthetic. There is no document upload, per-user ownership, persistence, paid provider, or generated answer in this release. Replace demo models and define task-specific quality and access rules before using predictions for real decisions.
