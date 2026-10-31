"""A real loopback HTTP journey, separate from the in-process API tests."""

import socket
import time
from threading import Thread

import httpx
import uvicorn


def test_signed_backend_can_search_over_http(identity: tuple[str, str, str]) -> None:
    token, _, _ = identity
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]

    config = uvicorn.Config(
        "kankal_ml.app:create_app",
        factory=True,
        host="127.0.0.1",
        port=port,
        access_log=False,
        log_config=None,
    )
    server = uvicorn.Server(config)
    thread = Thread(target=server.run, daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started:
                break
            if not thread.is_alive():
                raise AssertionError("Loopback service stopped during startup")
            time.sleep(0.05)
        else:
            raise AssertionError("Loopback service did not start")

        with httpx.Client(base_url=f"http://127.0.0.1:{port}", timeout=5) as client:
            assert client.get("/ready").status_code == 200
            response = client.post(
                "/v1/search",
                headers={"Authorization": f"Bearer {token}"},
                json={"query": "reset password"},
            )
        assert response.status_code == 200
        assert response.json()["matches"][0]["document_id"] == "account-access"
        assert response.headers["X-Model-Version"] == "demo-1"
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        assert not thread.is_alive()
