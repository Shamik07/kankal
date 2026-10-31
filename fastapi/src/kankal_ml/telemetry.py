"""Privacy-safe traces and metrics for fixed service operations."""

import json
import logging
import sys

from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


class _SafeExporterLog(logging.Filter):
    def __init__(self, signal: str) -> None:
        super().__init__()
        self.signal = signal

    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = json.dumps(
            {"event": "telemetry_export_issue", "signal": self.signal},
            separators=(",", ":"),
        )
        record.args = ()
        record.exc_info = None
        record.stack_info = None
        return True


def _configure_exporter_logs() -> None:
    for signal in ("trace", "metric"):
        name = f"opentelemetry.exporter.otlp.proto.http.{signal}_exporter"
        exporter_logger = logging.getLogger(name)
        if not any(
            isinstance(item, _SafeExporterLog) for item in exporter_logger.filters
        ):
            exporter_logger.addFilter(_SafeExporterLog(signal))
        if not exporter_logger.handlers:
            handler = logging.StreamHandler(sys.__stdout__)
            handler.setFormatter(logging.Formatter("%(message)s"))
            exporter_logger.addHandler(handler)
        exporter_logger.propagate = False


class Telemetry:
    def __init__(self, endpoint: str | None) -> None:
        resource = Resource.create({"service.name": "kankal-ml"})
        self.traces = TracerProvider(resource=resource)
        if endpoint:
            _configure_exporter_logs()
            self.traces.add_span_processor(
                BatchSpanProcessor(
                    OTLPSpanExporter(
                        endpoint=f"{endpoint.rstrip('/')}/v1/traces", timeout=3
                    ),
                    schedule_delay_millis=1000,
                )
            )
        readers = []
        if endpoint:
            readers.append(
                PeriodicExportingMetricReader(
                    OTLPMetricExporter(
                        endpoint=f"{endpoint.rstrip('/')}/v1/metrics", timeout=3
                    ),
                    export_interval_millis=1000,
                )
            )
        self.metrics = MeterProvider(resource=resource, metric_readers=readers)
        self.tracer = self.traces.get_tracer("kankal_ml")
        meter = self.metrics.get_meter("kankal_ml")
        self.requests = meter.create_counter("http.server.requests", unit="1")
        self.duration = meter.create_histogram("http.server.duration", unit="ms")
        self.inference = meter.create_counter("model.inference.calls", unit="1")

    def close(self) -> None:
        self.traces.shutdown()
        self.metrics.shutdown()
