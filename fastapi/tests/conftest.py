import json
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from kankal_ml.app import create_app


@pytest.fixture
def identity(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[str, str, str]]:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key()))
    public.update(kid="test-key", use="sig", alg="RS256")
    body = json.dumps({"keys": [public]}).encode()

    class JWKSHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, _format: str, *_args: Any) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), JWKSHandler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    issuer = "http://127.0.0.1/test-issuer"
    monkeypatch.setenv("KANKAL_OIDC_ISSUER", issuer)
    monkeypatch.setenv("KANKAL_OIDC_AUDIENCE", "kankal-ml")
    monkeypatch.setenv(
        "KANKAL_OIDC_JWKS_URL", f"http://127.0.0.1:{server.server_port}/jwks"
    )
    monkeypatch.setenv("KANKAL_ALLOWED_SUBJECTS", "backend-a")
    token = jwt.encode(
        {"iss": issuer, "aud": "kankal-ml", "sub": "backend-a", "exp": 4102444800},
        key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    disallowed = jwt.encode(
        {"iss": issuer, "aud": "kankal-ml", "sub": "backend-b", "exp": 4102444800},
        key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    expired = jwt.encode(
        {"iss": issuer, "aud": "kankal-ml", "sub": "backend-a", "exp": 1},
        key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    try:
        yield token, disallowed, expired
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


@pytest.fixture
def client(identity: tuple[str, str, str]) -> Iterator[tuple[TestClient, str, str]]:
    token, disallowed, _ = identity
    with TestClient(create_app()) as test_client:
        yield test_client, token, disallowed


@pytest.fixture
def collector(
    monkeypatch: pytest.MonkeyPatch,
) -> Iterator[list[tuple[str, bytes]]]:
    received: list[tuple[str, bytes]] = []

    class CollectorHandler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:
            size = int(self.headers["Content-Length"])
            received.append((self.path, self.rfile.read(size)))
            self.send_response(200)
            self.end_headers()

        def log_message(self, _format: str, *_args: Any) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), CollectorHandler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setenv("KANKAL_OTLP_ENDPOINT", f"http://127.0.0.1:{server.server_port}")
    try:
        yield received
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
