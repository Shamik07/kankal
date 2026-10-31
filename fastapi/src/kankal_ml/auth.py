"""OIDC service-token verification with a bounded JWKS cache."""

import asyncio
import time
from typing import Annotated, cast
from urllib.parse import urlparse

import httpx
import jwt
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

bearer = HTTPBearer(auto_error=False)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="KANKAL_", extra="ignore")

    oidc_issuer: str
    oidc_audience: str
    oidc_jwks_url: str
    allowed_subjects: str
    otlp_endpoint: str | None = None
    max_inference: int = Field(default=4, ge=1, le=32)

    @model_validator(mode="after")
    def validate_security(self) -> Settings:
        for value in (self.oidc_issuer, self.oidc_jwks_url):
            parsed = urlparse(value)
            if parsed.username or parsed.password or parsed.query or parsed.fragment:
                raise ValueError("OIDC URLs cannot contain credentials or query values")
            if parsed.scheme == "https" and parsed.hostname:
                continue
            if parsed.scheme == "http" and parsed.hostname in {
                "localhost",
                "127.0.0.1",
                "::1",
            }:
                continue
            raise ValueError("OIDC URLs must use HTTPS except on loopback")
        if not self.oidc_audience.strip() or not self.subjects:
            raise ValueError("OIDC audience and allowed subjects are required")
        return self

    @property
    def subjects(self) -> set[str]:
        return {
            part.strip() for part in self.allowed_subjects.split(",") if part.strip()
        }


class JWKS:
    def __init__(self, settings: Settings, client: httpx.AsyncClient) -> None:
        self.settings = settings
        self.client = client
        self.keys: dict[str, RSAPublicKey] = {}
        self.refreshed_at = 0.0
        self.last_unknown_refresh = 0.0
        self.lock = asyncio.Lock()

    @property
    def ready(self) -> bool:
        return bool(self.keys) and time.monotonic() - self.refreshed_at < 300

    async def refresh(self) -> None:
        async with self.lock:
            try:
                response = await self.client.get(self.settings.oidc_jwks_url)
                response.raise_for_status()
                payload = response.json()
                if not isinstance(payload, dict) or not isinstance(
                    payload.get("keys"), list
                ):
                    raise ValueError("Invalid key set")
                keys: dict[str, RSAPublicKey] = {}
                for item in payload["keys"]:
                    if not isinstance(item, dict) or item.get("kty") != "RSA":
                        continue
                    if (
                        item.get("alg", "RS256") != "RS256"
                        or item.get("use", "sig") != "sig"
                    ):
                        continue
                    if {"d", "p", "q", "dp", "dq", "qi", "oth"}.intersection(item):
                        continue
                    kid = item.get("kid")
                    if not isinstance(kid, str) or not kid or kid in keys:
                        raise ValueError("Invalid key identifier")
                    keys[kid] = cast(
                        RSAPublicKey, jwt.algorithms.RSAAlgorithm.from_jwk(item)
                    )
                if not keys:
                    raise ValueError("No usable signing keys")
            except httpx.HTTPError, jwt.PyJWTError, ValueError, KeyError, TypeError:
                raise RuntimeError("OIDC keys unavailable") from None
            self.keys = keys
            self.refreshed_at = time.monotonic()

    async def verify(self, token: str) -> str:
        try:
            header = jwt.get_unverified_header(token)
            if header.get("alg") != "RS256" or not isinstance(header.get("kid"), str):
                raise jwt.InvalidTokenError
            if not self.ready:
                await self.refresh()
            elif (
                header["kid"] not in self.keys
                and time.monotonic() - self.last_unknown_refresh >= 30
            ):
                self.last_unknown_refresh = time.monotonic()
                await self.refresh()
            key = self.keys.get(header["kid"])
            if key is None:
                raise jwt.InvalidTokenError
            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                issuer=self.settings.oidc_issuer,
                audience=self.settings.oidc_audience,
                options={"require": ["iss", "aud", "sub", "exp"]},
            )
        except RuntimeError as exc:
            raise HTTPException(
                status_code=503, detail="Identity keys unavailable"
            ) from exc
        except jwt.PyJWTError as exc:
            raise HTTPException(
                status_code=401,
                detail="Invalid service token",
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc
        subject = claims["sub"]
        if subject not in self.settings.subjects:
            raise HTTPException(status_code=403, detail="Caller not allowed")
        return str(subject)


async def require_subject(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> str:
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Service token required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    jwks: JWKS = request.app.state.jwks
    return await jwks.verify(credentials.credentials)
