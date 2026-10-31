use std::env;

use opentelemetry::trace::TracerProvider as _;
use opentelemetry_otlp::WithExportConfig as _;
use opentelemetry_sdk::Resource;
use opentelemetry_sdk::metrics::SdkMeterProvider;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::SubscriberExt as _;
use tracing_subscriber::util::SubscriberInitExt as _;

pub struct Telemetry {
    traces: Option<SdkTracerProvider>,
    metrics: Option<SdkMeterProvider>,
}

pub fn init() -> Result<Telemetry, &'static str> {
    opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());
    let logs = tracing_subscriber::fmt::layer()
        .json()
        .with_target(false)
        .with_current_span(true);
    let filter = EnvFilter::new("kankal_grpc=info");
    let Ok(endpoint) = env::var("OTEL_EXPORTER_OTLP_ENDPOINT") else {
        tracing_subscriber::registry()
            .with(filter)
            .with(logs)
            .init();
        return Ok(Telemetry {
            traces: None,
            metrics: None,
        });
    };
    let resource = Resource::builder().with_service_name("kankal-grpc").build();
    let span_exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint(&endpoint)
        .build()
        .map_err(|_| "invalid trace exporter configuration")?;
    let metric_exporter = opentelemetry_otlp::MetricExporter::builder()
        .with_tonic()
        .with_endpoint(&endpoint)
        .build()
        .map_err(|_| "invalid metric exporter configuration")?;
    let traces = SdkTracerProvider::builder()
        .with_resource(resource.clone())
        .with_batch_exporter(span_exporter)
        .build();
    let metrics = SdkMeterProvider::builder()
        .with_resource(resource)
        .with_periodic_exporter(metric_exporter)
        .build();
    opentelemetry::global::set_meter_provider(metrics.clone());
    tracing_subscriber::registry()
        .with(filter)
        .with(logs)
        .with(tracing_opentelemetry::layer().with_tracer(traces.tracer("kankal-grpc")))
        .init();
    Ok(Telemetry {
        traces: Some(traces),
        metrics: Some(metrics),
    })
}

impl Telemetry {
    pub fn shutdown(self) {
        if let Some(metrics) = self.metrics
            && metrics.shutdown().is_err()
        {
            tracing::error!(outcome = "metric_export_failed");
        }
        if let Some(traces) = self.traces
            && traces.shutdown().is_err()
        {
            tracing::error!(outcome = "trace_export_failed");
        }
    }
}
