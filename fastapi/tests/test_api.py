import base64
import json
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from kankal_ml.app import create_app


def test_live_reports_running_process(client: tuple[TestClient, str, str]) -> None:
    api, _, _ = client
    response = api.get("/live")
    assert response.status_code == 200
    assert response.json() == {"status": "live"}


def test_search_returns_ranked_passage(
    client: tuple[TestClient, str, str], capfd: pytest.CaptureFixture[str]
) -> None:
    api, token, _ = client
    response = api.post(
        "/v1/search",
        headers={"Authorization": f"Bearer {token}"},
        json={"query": "How do I reset my password?", "limit": 3},
    )
    assert response.status_code == 200
    results = response.json()["matches"]
    assert results
    assert results[0]["document_id"] == "account-access"
    assert results[0]["score"] > 0
    logs = capfd.readouterr().out
    assert '"route": "/v1/search"' in logs
    assert "How do I reset my password?" not in logs
    assert token not in logs


def test_text_journeys_return_useful_results(
    client: tuple[TestClient, str, str],
) -> None:
    api, token, _ = client
    headers = {"Authorization": f"Bearer {token}"}

    tagging = api.post(
        "/v1/text/tags", headers=headers, json={"text": "Reset my password"}
    )
    assert tagging.status_code == 200
    assert tagging.json()["label"] == "account"

    phrases = api.post(
        "/v1/text/keyphrases",
        headers=headers,
        json={"text": "Reset my password and account access", "limit": 3},
    )
    assert phrases.status_code == 200
    assert any("reset" in row["phrase"] for row in phrases.json()["phrases"])

    topics = api.post(
        "/v1/text/topics",
        headers=headers,
        json={"text": "The monthly invoice and billing cycle"},
    )
    assert topics.status_code == 200
    assert topics.json()["sample_topic"] == "billing"

    duplicates = api.post(
        "/v1/text/duplicates",
        headers=headers,
        json={"text": "I cannot log in to my account", "limit": 3},
    )
    assert duplicates.status_code == 200
    assert duplicates.json()["matches"][0]["ticket_id"] == "ticket-1"


def test_catalog_recommends_related_item(client: tuple[TestClient, str, str]) -> None:
    api, token, _ = client
    response = api.post(
        "/v1/recommendations",
        headers={"Authorization": f"Bearer {token}"},
        json={"item_id": "notebook", "limit": 3},
    )
    assert response.status_code == 200
    assert response.json()["items"][0]["item_id"] == "journal"


def test_numeric_journeys_distinguish_inputs(
    client: tuple[TestClient, str, str],
) -> None:
    api, token, _ = client
    headers = {"Authorization": f"Bearer {token}"}

    normal = api.post(
        "/v1/anomalies", headers=headers, json={"temperature": 20, "vibration": 40}
    )
    unusual = api.post(
        "/v1/anomalies", headers=headers, json={"temperature": 120, "vibration": 180}
    )
    assert normal.status_code == unusual.status_code == 200
    assert normal.json()["anomaly"] is False
    assert unusual.json()["anomaly"] is True

    low = api.post("/v1/risks", headers=headers, json={"age": 1, "temperature": 20})
    high = api.post("/v1/risks", headers=headers, json={"age": 12, "temperature": 85})
    assert low.status_code == high.status_code == 200
    assert low.json()["risk"] < high.json()["risk"]
    assert low.json()["flagged"] is False
    assert high.json()["flagged"] is True

    price = api.post(
        "/v1/predictions", headers=headers, json={"quantity": 2, "grade": 2}
    )
    assert price.status_code == 200
    assert 15 < price.json()["estimated_value"] < 30

    forecast = api.post(
        "/v1/forecasts", headers=headers, json={"series_id": "notebooks", "horizon": 3}
    )
    assert forecast.status_code == 200
    assert len(forecast.json()["values"]) == 3
    assert forecast.json()["values"][0] < forecast.json()["values"][-1]


def test_compute_requires_a_service_token(
    client: tuple[TestClient, str, str], identity: tuple[str, str, str]
) -> None:
    api, _, disallowed = client
    expired_token = identity[2]
    missing = api.post("/v1/search", json={"query": "password"})
    invalid = api.post(
        "/v1/search",
        headers={"Authorization": "Bearer not-a-token"},
        json={"query": "password"},
    )
    assert missing.status_code == invalid.status_code == 401
    assert missing.headers["WWW-Authenticate"] == "Bearer"
    assert invalid.headers["WWW-Authenticate"] == "Bearer"
    forbidden = api.post(
        "/v1/search",
        headers={"Authorization": f"Bearer {disallowed}"},
        json={"query": "password"},
    )
    assert forbidden.status_code == 403
    expired = api.post(
        "/v1/search",
        headers={"Authorization": f"Bearer {expired_token}"},
        json={"query": "password"},
    )
    assert expired.status_code == 401


def test_unknown_signing_key_cannot_force_repeated_identity_fetches(
    client: tuple[TestClient, str, str], monkeypatch: pytest.MonkeyPatch
) -> None:
    api, _, _ = client
    header = (
        base64.urlsafe_b64encode(
            json.dumps({"alg": "RS256", "kid": "unknown"}).encode()
        )
        .rstrip(b"=")
        .decode()
    )
    unknown = f"{header}.e30.c2ln"
    get = AsyncMock(wraps=api.app.state.jwks.client.get)
    monkeypatch.setattr(api.app.state.jwks.client, "get", get)

    for _ in range(2):
        response = api.post(
            "/v1/search",
            headers={"Authorization": f"Bearer {unknown}"},
            json={"query": "password"},
        )
        assert response.status_code == 401
    assert get.await_count == 1


def test_text_models_abstain_without_known_terms(
    client: tuple[TestClient, str, str],
) -> None:
    api, token, _ = client
    headers = {"Authorization": f"Bearer {token}"}
    tagging = api.post("/v1/text/tags", headers=headers, json={"text": "zzzzzzzzzz"})
    grouping = api.post("/v1/text/topics", headers=headers, json={"text": "zzzzzzzzzz"})
    assert tagging.status_code == grouping.status_code == 200
    assert tagging.json() == {"label": "unknown", "score": 0.0}
    assert grouping.json() == {"group": -1, "sample_topic": "unknown"}


def test_input_limits_and_unknown_catalog_item(
    client: tuple[TestClient, str, str],
) -> None:
    api, token, _ = client
    headers = {"Authorization": f"Bearer {token}"}
    oversized = api.post("/v1/search", headers=headers, json={"query": "a" * 501})
    blank = api.post("/v1/search", headers=headers, json={"query": "   "})
    excessive_body = api.post(
        "/v1/text/tags", headers=headers, json={"text": "x" * 17000}
    )
    unknown = api.post(
        "/v1/recommendations", headers=headers, json={"item_id": "missing"}
    )
    assert oversized.status_code == 422
    assert "a" * 501 not in oversized.text
    assert blank.status_code == 422
    assert excessive_body.status_code == 413
    assert unknown.status_code == 404


def test_readiness_recovers_after_identity_key_expiry(
    client: tuple[TestClient, str, str],
) -> None:
    api, _, _ = client
    assert api.get("/ready").status_code == 200
    api.app.state.jwks.refreshed_at = 0
    assert api.get("/ready").status_code == 200
    assert api.get("/live").status_code == 200


def test_missing_identity_keys_prevent_startup(
    identity: tuple[str, str, str], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("KANKAL_OIDC_JWKS_URL", "http://127.0.0.1:1/jwks")
    with pytest.raises(RuntimeError, match="OIDC keys unavailable"):
        with TestClient(create_app()):
            pass


def test_openapi_and_scalar_describe_ten_protected_journeys(
    client: tuple[TestClient, str, str],
) -> None:
    api, _, _ = client
    spec = api.get("/openapi.json")
    docs = api.get("/docs")
    script = api.get("/static/scalar.js")

    assert spec.status_code == docs.status_code == script.status_code == 200
    operations = [
        path for path, methods in spec.json()["paths"].items() if "post" in methods
    ]
    assert len(operations) == 10
    assert all(spec.json()["paths"][path]["post"]["security"] for path in operations)
    assert "/static/scalar.js" in docs.text
    assert "/openapi.json" in docs.text
    assert "@scalar/api-reference" in script.text


def test_unexpected_model_error_is_fixed_and_private(
    client: tuple[TestClient, str, str],
    monkeypatch: pytest.MonkeyPatch,
    capfd: pytest.CaptureFixture[str],
) -> None:
    api, token, _ = client
    sensitive = "private customer text"

    def fail(_query: str, _limit: int) -> None:
        raise RuntimeError(sensitive)

    monkeypatch.setattr(api.app.state.bundle, "search", fail)
    response = api.post(
        "/v1/search",
        headers={"Authorization": f"Bearer {token}"},
        json={"query": sensitive},
    )
    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error"}
    logs = capfd.readouterr().out
    assert '"outcome": "unexpected"' in logs
    assert sensitive not in logs
    assert token not in logs


def test_traces_and_metrics_export_without_submitted_text(
    identity: tuple[str, str, str], collector: list[tuple[str, bytes]]
) -> None:
    token, _, _ = identity
    submitted = "private account question"
    with TestClient(create_app()) as api:
        response = api.post(
            "/v1/search",
            headers={"Authorization": f"Bearer {token}"},
            json={"query": submitted},
        )
    assert response.status_code == 200
    assert {path for path, _ in collector} >= {"/v1/traces", "/v1/metrics"}
    assert all(submitted.encode() not in body for _, body in collector)


def test_failed_telemetry_export_does_not_log_endpoint_or_input(
    identity: tuple[str, str, str],
    monkeypatch: pytest.MonkeyPatch,
    capfd: pytest.CaptureFixture[str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    token, _, _ = identity
    monkeypatch.setenv("KANKAL_OTLP_ENDPOINT", "http://127.0.0.1:1")
    submitted = "private telemetry input"
    with TestClient(create_app()) as api:
        response = api.post(
            "/v1/search",
            headers={"Authorization": f"Bearer {token}"},
            json={"query": submitted},
        )
    assert response.status_code == 200
    output = capfd.readouterr()
    emitted = output.out + output.err + caplog.text
    assert '"event":"telemetry_export_issue"' in emitted
    assert "127.0.0.1:1" not in emitted
    assert "HTTPConnectionPool" not in emitted
    assert submitted not in emitted
