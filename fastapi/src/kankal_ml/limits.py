"""Bound request bodies before JSON parsing or model inference."""

import json
import logging
from uuid import uuid4

from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

MAX_BODY_BYTES = 16 * 1024
logger = logging.getLogger("kankal_ml")


class BodyLimitMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or not scope["path"].startswith("/v1/"):
            await self.app(scope, receive, send)
            return

        messages: list[Message] = []
        total = 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            total += len(message.get("body", b""))
            if total > MAX_BODY_BYTES:
                request_id = uuid4().hex
                logger.info(
                    json.dumps(
                        {
                            "event": "request",
                            "request_id": request_id,
                            "outcome": "body_limit",
                            "method": scope["method"],
                            "status": 413,
                        }
                    )
                )
                response = JSONResponse(
                    status_code=413,
                    content={"detail": "Request body too large"},
                    headers={"X-Request-ID": request_id},
                )
                await response(scope, receive, send)
                return
            messages.append(message)
            if not message.get("more_body", False):
                break

        async def replay() -> Message:
            if messages:
                return messages.pop(0)
            return await receive()

        await self.app(scope, replay, send)
