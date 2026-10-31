FROM python:3.14.7-slim

COPY --from=ghcr.io/astral-sh/uv:0.12.2 /uv /uvx /bin/
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="/app/.venv/bin:${PATH}"

COPY pyproject.toml uv.lock README.md ./
COPY src ./src
RUN uv sync --locked --no-dev --no-cache
RUN .venv/bin/python -c "from kankal_ml.models import ModelBundle; ModelBundle()"

RUN useradd --system --uid 10001 --no-create-home kankal
USER kankal
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/live', timeout=3)" || exit 1
CMD ["uvicorn", "kankal_ml.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--no-access-log"]
