"""FastAPI service boundary for ten read-only demonstration journeys."""

import json
import logging
import sys
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from threading import BoundedSemaphore
from typing import Annotated, cast
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from scalar_fastapi import AgentScalarConfig, get_scalar_api_reference
from starlette.middleware.base import RequestResponseEndpoint

from kankal_ml.auth import JWKS, Settings, require_subject
from kankal_ml.contracts import (
    AnomalyInput,
    AnomalyOutput,
    Duplicate,
    DuplicateOutput,
    ErrorOutput,
    ForecastInput,
    ForecastOutput,
    LimitedTextInput,
    Passage,
    Phrase,
    PhraseOutput,
    PriceInput,
    PriceOutput,
    Recommendation,
    RecommendationInput,
    RecommendationOutput,
    RiskInput,
    RiskOutput,
    SearchInput,
    SearchOutput,
    TagOutput,
    TextInput,
    TopicOutput,
)
from kankal_ml.limits import BodyLimitMiddleware
from kankal_ml.models import ASSETS, ModelBundle
from kankal_ml.telemetry import Telemetry

logger = logging.getLogger("kankal_ml")


def configure_logging() -> None:
    if not logger.handlers:
        handler = logging.StreamHandler(sys.__stdout__)
        handler.setFormatter(logging.Formatter("%(message)s"))
        logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    settings = Settings()  # type: ignore[call-arg]  # Values come from environment.
    async with httpx.AsyncClient(timeout=httpx.Timeout(3.0)) as client:
        jwks = JWKS(settings, client)
        await jwks.refresh()
        app.state.jwks = jwks
        app.state.bundle = ModelBundle()
        app.state.capacity = BoundedSemaphore(settings.max_inference)
        app.state.telemetry = Telemetry(settings.otlp_endpoint)
        try:
            yield
        finally:
            app.state.telemetry.close()


async def capacity(request: Request) -> AsyncIterator[None]:
    semaphore: BoundedSemaphore = request.app.state.capacity
    if not semaphore.acquire(blocking=False):
        raise HTTPException(status_code=503, detail="Inference capacity reached")
    try:
        telemetry: Telemetry = request.app.state.telemetry
        route = request.scope.get("route")
        operation = route.path if route is not None else "unknown"
        with telemetry.tracer.start_as_current_span("model.inference") as span:
            span.set_attribute("model.version", request.app.state.bundle.version)
            span.set_attribute("model.operation", operation)
            telemetry.inference.add(1, {"operation": operation})
            yield
    finally:
        semaphore.release()


def bundle(request: Request) -> ModelBundle:
    return cast(ModelBundle, request.app.state.bundle)


Model = Annotated[ModelBundle, Depends(bundle)]
router = APIRouter(
    prefix="/v1",
    dependencies=[Depends(require_subject), Depends(capacity)],
    responses={
        401: {"model": ErrorOutput, "description": "Missing or invalid service token"},
        403: {"model": ErrorOutput, "description": "Caller is not allowed"},
        413: {"model": ErrorOutput, "description": "Request body is too large"},
        422: {"model": ErrorOutput, "description": "Invalid request"},
        500: {"model": ErrorOutput, "description": "Unexpected internal failure"},
        503: {
            "model": ErrorOutput,
            "description": "Identity keys or inference capacity unavailable",
        },
    },
)


@router.post("/search", response_model=SearchOutput, tags=["Text"])
def search(payload: SearchInput, model: Model) -> SearchOutput:
    return SearchOutput(
        matches=[
            Passage.model_validate(row)
            for row in model.search(payload.query, payload.limit)
        ]
    )


@router.post("/text/tags", response_model=TagOutput, tags=["Text"])
def tags(payload: TextInput, model: Model) -> TagOutput:
    return TagOutput(**model.tag(payload.text))


@router.post("/text/keyphrases", response_model=PhraseOutput, tags=["Text"])
def keyphrases(payload: LimitedTextInput, model: Model) -> PhraseOutput:
    return PhraseOutput(
        phrases=[
            Phrase.model_validate(row)
            for row in model.keyphrases(payload.text, payload.limit)
        ]
    )


@router.post("/text/topics", response_model=TopicOutput, tags=["Text"])
def topics(payload: TextInput, model: Model) -> TopicOutput:
    return TopicOutput(**model.topic(payload.text))


@router.post("/text/duplicates", response_model=DuplicateOutput, tags=["Text"])
def duplicates(payload: LimitedTextInput, model: Model) -> DuplicateOutput:
    return DuplicateOutput(
        matches=[
            Duplicate.model_validate(row)
            for row in model.duplicates(payload.text, payload.limit)
        ]
    )


@router.post(
    "/recommendations",
    response_model=RecommendationOutput,
    tags=["Catalog"],
    responses={404: {"model": ErrorOutput, "description": "Item not found"}},
)
def recommendations(payload: RecommendationInput, model: Model) -> RecommendationOutput:
    items = model.recommendations(payload.item_id, payload.limit)
    if items is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return RecommendationOutput(
        items=[Recommendation.model_validate(row) for row in items]
    )


@router.post("/anomalies", response_model=AnomalyOutput, tags=["Numeric"])
def anomalies(payload: AnomalyInput, model: Model) -> AnomalyOutput:
    return AnomalyOutput(**model.anomaly(payload.temperature, payload.vibration))


@router.post("/risks", response_model=RiskOutput, tags=["Numeric"])
def risks(payload: RiskInput, model: Model) -> RiskOutput:
    return RiskOutput(**model.risk(payload.age, payload.temperature))


@router.post("/predictions", response_model=PriceOutput, tags=["Numeric"])
def predictions(payload: PriceInput, model: Model) -> PriceOutput:
    return PriceOutput(**model.price(payload.quantity, payload.grade))


@router.post(
    "/forecasts",
    response_model=ForecastOutput,
    tags=["Numeric"],
    responses={404: {"model": ErrorOutput, "description": "Series not found"}},
)
def forecasts(payload: ForecastInput, model: Model) -> ForecastOutput:
    values = model.forecast(payload.series_id, payload.horizon)
    if values is None:
        raise HTTPException(status_code=404, detail="Series not found")
    return ForecastOutput(values=values)


def create_app() -> FastAPI:
    app = FastAPI(
        title="Kankal AI/ML API",
        version="0.1.0",
        description=(
            "Offline demonstration models. Outputs are illustrative, "
            "not decision-grade."
        ),
        lifespan=lifespan,
        docs_url=None,
        redoc_url=None,
    )
    app.mount("/static", StaticFiles(directory=ASSETS / "static"), name="static")

    @app.exception_handler(RequestValidationError)
    async def invalid_request(
        _request: Request, _exc: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(status_code=422, content={"detail": "Invalid request"})

    @app.middleware("http")
    async def outcomes(
        request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        started = time.monotonic()
        request_id = uuid4().hex
        telemetry: Telemetry = request.app.state.telemetry
        with telemetry.tracer.start_as_current_span("http.server") as span:
            try:
                response = await call_next(request)
            except Exception:
                response = JSONResponse(
                    status_code=500, content={"detail": "Internal server error"}
                )
                span.set_attribute("http.response.status_code", 500)
                logger.error(
                    json.dumps(
                        {
                            "event": "request",
                            "outcome": "unexpected",
                            "method": request.method,
                            "status": 500,
                        }
                    )
                )
            route = request.scope.get("route")
            route_name = route.path if route is not None else "unmatched"
            span.set_attribute("http.route", route_name)
            span.set_attribute("http.request.method", request.method)
            span.set_attribute("http.response.status_code", response.status_code)
        route = request.scope.get("route")
        route_name = route.path if route is not None else "unmatched"
        elapsed = round((time.monotonic() - started) * 1000, 2)
        attributes = {
            "route": route_name,
            "method": request.method,
            "status": response.status_code,
        }
        telemetry.requests.add(1, attributes)
        telemetry.duration.record(elapsed, attributes)
        logger.info(
            json.dumps(
                {
                    "event": "request",
                    "request_id": request_id,
                    "route": route_name,
                    "method": request.method,
                    "status": response.status_code,
                    "duration_ms": elapsed,
                }
            )
        )
        response.headers["X-Request-ID"] = request_id
        if request.url.path.startswith("/v1/") and hasattr(request.app.state, "bundle"):
            response.headers["X-Model-Version"] = request.app.state.bundle.version
        return response

    @app.get("/live", tags=["Health"])
    def live() -> dict[str, str]:
        return {"status": "live"}

    @app.get(
        "/ready",
        tags=["Health"],
        responses={503: {"model": ErrorOutput, "description": "Service not ready"}},
    )
    async def ready(request: Request) -> dict[str, str]:
        jwks: JWKS = request.app.state.jwks
        if not jwks.ready:
            try:
                await jwks.refresh()
            except RuntimeError as exc:
                raise HTTPException(
                    status_code=503, detail="Service not ready"
                ) from exc
        if not hasattr(request.app.state, "bundle"):
            raise HTTPException(status_code=503, detail="Service not ready")
        return {"status": "ready"}

    @app.get("/docs", include_in_schema=False)
    def scalar() -> Response:
        return get_scalar_api_reference(
            openapi_url=app.openapi_url,
            title=app.title,
            agent=AgentScalarConfig(disabled=True),
            scalar_proxy_url="",
            persist_auth=False,
            scalar_js_url="/static/scalar.js",
            scalar_favicon_url="/static/favicon.svg",
            with_default_fonts=False,
            show_developer_tools="never",
            telemetry=False,
        )

    app.include_router(router)
    app.add_middleware(BodyLimitMiddleware)
    return app
