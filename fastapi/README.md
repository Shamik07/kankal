# Kankal FastAPI AI/ML starter

This standalone service demonstrates ten read-only AI/ML journeys with small, bundled, synthetic data. It uses FastAPI, Pydantic, scikit-learn, OIDC service tokens, structured outcome logs, optional OpenTelemetry export, OpenAPI, and an offline Scalar reference. It does not connect to Kankal's other starters. The demo models show working contracts and operations; their outputs are **not decision-grade predictions**.

## Run

Use Python 3.14 and `uv`. From this directory:

```sh
uv sync --locked
export KANKAL_OIDC_ISSUER='https://identity.example.com/'
export KANKAL_OIDC_AUDIENCE='kankal-ml'
export KANKAL_OIDC_JWKS_URL='https://identity.example.com/.well-known/jwks.json'
export KANKAL_ALLOWED_SUBJECTS='your-backend-service'
uv run --locked uvicorn 'kankal_ml.app:create_app' --factory --host 127.0.0.1 --port 8000 --workers 1 --no-access-log
```

Use an identity provider that issues RS256 tokens with `iss`, `aud`, `sub`, and `exp` claims and publishes its public keys as JWKS. The issuer and JWKS URL must use HTTPS, except for loopback-only test services. There is no development authentication bypass. Do not place tokens or private keys in this repository.

`GET /live` checks the process. `GET /ready` checks the model bundle and refreshes identity keys if needed. `GET /openapi.json` is the machine-readable contract; `GET /docs` serves Scalar from a pinned local script. Keep these documentation routes on an internal network or protect them at the ingress. All ten `/v1` routes require an allowed service token. The full request and response contract is in [docs/API.md](docs/API.md).

The service holds only bundled models and synthetic examples. It does not save requests or results, download models at startup, call an AI provider, or cache inference results. Each request body is capped at 16 KiB; text, numeric ranges, and result counts have smaller field limits. Inference is bounded to four concurrent calls by default (`KANKAL_MAX_INFERENCE`, 1 to 32). One worker is recommended because each worker loads its own model bundle. For multi-replica deployments, configure rate limits at a shared ingress.

Logs contain fixed outcomes, method, route template, status, duration, and a generated request ID. Do not enable Uvicorn access logs, which can include raw request paths. When `KANKAL_OTLP_ENDPOINT` points to an OTLP HTTP collector, the service exports request and inference traces plus request count, duration, and inference count. Export failures produce a fixed JSON outcome without a raw connection error. Telemetry contains no submitted text or token values. Tests use only loopback services.

For deployment, terminate HTTPS at a trusted ingress and keep the container's HTTP port private. Set memory and CPU limits after measuring the intended hardware. The Dockerfile uses one process and a non-root user. `/ready` is the readiness probe and `/live` is the liveness probe. A real product must replace the synthetic data and demo artifacts, set model-specific quality gates, and review its input retention and licensing needs.

## Rebuild demonstration models

The versioned artifacts in `src/kankal_ml/models/` are built from `src/kankal_ml/data/demo.json`:

```sh
uv run --locked python scripts/build_models.py
```

The script refreshes artifact hashes in the manifest. `skops` archive bytes include serializer metadata, so repeated builds can have different hashes even when the resulting predictions match. Review changed models and run the API and quality checks before keeping rebuilt artifacts. The service verifies each artifact against the manifest before loading it and never loads models from requests.

## Checks

```sh
uv run --locked pytest -q --junitxml=pytest-results.xml
uv run --locked ruff format --check src tests scripts
uv run --locked ruff check src tests scripts
uv run --locked mypy
uv build --no-sources
uv run --locked pip-audit
```

The tests cover all ten routes, signed-token access and denial, input limits, readiness recovery, OpenAPI and Scalar, safe errors, local OTLP export, and a real loopback Uvicorn search journey. The CI workflow retains the JUnit report and rejects an empty or skipped test run.
