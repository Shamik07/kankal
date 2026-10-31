use jsonwebtoken::jwk::Jwk;
use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
use kankal_grpc::auth::{AuthConfig, Authenticator};
use kankal_grpc::item_service;
use kankal_grpc::proto::items_service_client::ItemsServiceClient;
use kankal_grpc::proto::{
    CreateItemRequest, DeleteItemRequest, GetItemRequest, ListItemsRequest, UpdateItemRequest,
};
#[cfg(unix)]
use opentelemetry_proto::tonic::collector::metrics::v1::{
    ExportMetricsServiceRequest, ExportMetricsServiceResponse,
    metrics_service_server::{MetricsService, MetricsServiceServer},
};
#[cfg(unix)]
use opentelemetry_proto::tonic::collector::trace::v1::{
    ExportTraceServiceRequest, ExportTraceServiceResponse,
    trace_service_server::{TraceService, TraceServiceServer},
};
use rsa::RsaPrivateKey;
use rsa::pkcs1::EncodeRsaPrivateKey;
use std::process::{Child, Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tonic::{Code, Request};
use tonic_health::pb::HealthCheckRequest;
use tonic_health::pb::health_client::HealthClient;
use tonic_reflection::pb::v1::ServerReflectionRequest;
use tonic_reflection::pb::v1::server_reflection_client::ServerReflectionClient;
use tonic_reflection::pb::v1::server_reflection_request::MessageRequest;
use tonic_reflection::pb::v1::server_reflection_response::MessageResponse;

#[tokio::test]
async fn item_calls_require_authentication() {
    let (mut client, server) =
        start_app("http://127.0.0.1:9/issuer", "http://127.0.0.1:9/jwks").await;
    assert_eq!(
        client
            .list_items(ListItemsRequest {})
            .await
            .expect_err("list must reject anonymous call")
            .code(),
        Code::Unauthenticated
    );
    assert_eq!(
        client
            .create_item(CreateItemRequest {
                title: "x".into(),
                description: String::new()
            })
            .await
            .expect_err("create must reject anonymous call")
            .code(),
        Code::Unauthenticated
    );
    assert_eq!(
        client
            .get_item(GetItemRequest { id: 1 })
            .await
            .expect_err("get must reject anonymous call")
            .code(),
        Code::Unauthenticated
    );
    assert_eq!(
        client
            .update_item(UpdateItemRequest {
                id: 1,
                title: "x".into(),
                description: String::new()
            })
            .await
            .expect_err("update must reject anonymous call")
            .code(),
        Code::Unauthenticated
    );
    assert_eq!(
        client
            .delete_item(DeleteItemRequest { id: 1 })
            .await
            .expect_err("delete must reject anonymous call")
            .code(),
        Code::Unauthenticated
    );
    server.abort();
}

#[tokio::test]
async fn authenticated_item_journey() {
    let (issuer, jwks_url, signing_key, key_server) = start_identity_provider().await;
    let token = signed_token(&signing_key, &issuer, "kankal-test", "test-service", 3600);
    let (mut client, server) = start_app(&issuer, &jwks_url).await;
    let result = client
        .list_items(authorized(&token, ListItemsRequest {}))
        .await
        .expect("authenticated list");
    assert!(result.into_inner().items.is_empty());

    let create = authorized(
        &token,
        CreateItemRequest {
            title: "Buy tea".to_owned(),
            description: "Green tea".to_owned(),
        },
    );
    let created = client
        .create_item(create)
        .await
        .expect("create item")
        .into_inner()
        .item
        .expect("created item");
    assert_eq!(created.title, "Buy tea");
    assert_eq!(created.description, "Green tea");
    assert_ne!(created.id, 0);

    let found = client
        .get_item(authorized(&token, GetItemRequest { id: created.id }))
        .await
        .expect("get item")
        .into_inner()
        .item
        .expect("found item");
    assert_eq!(found, created);

    let updated = client
        .update_item(authorized(
            &token,
            UpdateItemRequest {
                id: created.id,
                title: "Buy coffee".to_owned(),
                description: "Whole beans".to_owned(),
            },
        ))
        .await
        .expect("update item")
        .into_inner()
        .item
        .expect("updated item");
    assert_eq!(updated.title, "Buy coffee");
    let listed = client
        .list_items(authorized(&token, ListItemsRequest {}))
        .await
        .expect("list items")
        .into_inner();
    assert_eq!(listed.items, vec![updated]);

    client
        .delete_item(authorized(&token, DeleteItemRequest { id: created.id }))
        .await
        .expect("delete item");
    let after_delete = client
        .get_item(authorized(&token, GetItemRequest { id: created.id }))
        .await
        .expect_err("deleted item is absent");
    assert_eq!(after_delete.code(), Code::NotFound);
    server.abort();
    key_server.abort();
}

#[tokio::test]
async fn service_tokens_enforce_audience_subject_and_expiration() {
    let (issuer, jwks_url, signing_key, key_server) = start_identity_provider().await;
    let (mut client, server) = start_app(&issuer, &jwks_url).await;
    for (audience, subject, expires_in, expected) in [
        (
            "wrong-audience",
            "test-service",
            3600,
            Code::Unauthenticated,
        ),
        ("kankal-test", "other-service", 3600, Code::PermissionDenied),
        ("kankal-test", "test-service", -3600, Code::Unauthenticated),
    ] {
        let token = signed_token(&signing_key, &issuer, audience, subject, expires_in);
        let error = client
            .list_items(authorized(&token, ListItemsRequest {}))
            .await
            .expect_err("invalid service token");
        assert_eq!(error.code(), expected);
    }
    let wrong_issuer = signed_token(
        &signing_key,
        "http://127.0.0.1/other",
        "kankal-test",
        "test-service",
        3600,
    );
    assert_eq!(
        client
            .list_items(authorized(&wrong_issuer, ListItemsRequest {}))
            .await
            .expect_err("wrong issuer")
            .code(),
        Code::Unauthenticated
    );
    let valid = signed_token(&signing_key, &issuer, "kankal-test", "test-service", 3600);
    let mut parts: Vec<String> = valid.split('.').map(str::to_owned).collect();
    let replacement = if parts[2].starts_with('A') { "B" } else { "A" };
    parts[2].replace_range(0..1, replacement);
    let forged = parts.join(".");
    assert_eq!(
        client
            .list_items(authorized(&forged, ListItemsRequest {}))
            .await
            .expect_err("invalid signature")
            .code(),
        Code::Unauthenticated
    );
    server.abort();
    key_server.abort();
}

#[tokio::test]
async fn item_boundary_rejects_invalid_fields_and_large_messages() {
    let (issuer, jwks_url, signing_key, key_server) = start_identity_provider().await;
    let token = signed_token(&signing_key, &issuer, "kankal-test", "test-service", 3600);
    let (mut client, server) = start_app(&issuer, &jwks_url).await;
    for title in [" ".to_owned(), "x".repeat(201)] {
        let error = client
            .create_item(authorized(
                &token,
                CreateItemRequest {
                    title,
                    description: String::new(),
                },
            ))
            .await
            .expect_err("invalid item");
        assert_eq!(error.code(), Code::InvalidArgument);
    }
    let error = client
        .create_item(authorized(
            &token,
            CreateItemRequest {
                title: "Valid".into(),
                description: "x".repeat(2001),
            },
        ))
        .await
        .expect_err("long description");
    assert_eq!(error.code(), Code::InvalidArgument);
    let error = client
        .get_item(authorized(&token, GetItemRequest { id: 0 }))
        .await
        .expect_err("zero id");
    assert_eq!(error.code(), Code::InvalidArgument);
    let error = client
        .get_item(authorized(&token, GetItemRequest { id: 99 }))
        .await
        .expect_err("missing id");
    assert_eq!(error.code(), Code::NotFound);
    let error = client
        .create_item(authorized(
            &token,
            CreateItemRequest {
                title: "x".repeat(20_000),
                description: String::new(),
            },
        ))
        .await
        .expect_err("large message");
    assert_eq!(error.code(), Code::OutOfRange);
    let listed = client
        .list_items(authorized(&token, ListItemsRequest {}))
        .await
        .expect("list after rejection")
        .into_inner();
    assert!(listed.items.is_empty());
    server.abort();
    key_server.abort();
}

#[tokio::test]
async fn item_store_rejects_creation_after_capacity() {
    let (issuer, jwks_url, signing_key, key_server) = start_identity_provider().await;
    let token = signed_token(&signing_key, &issuer, "kankal-test", "test-service", 3600);
    let (mut client, server) = start_app(&issuer, &jwks_url).await;
    for index in 0..1_000 {
        client
            .create_item(authorized(
                &token,
                CreateItemRequest {
                    title: format!("Item {index}"),
                    description: String::new(),
                },
            ))
            .await
            .expect("item within capacity");
    }
    let error = client
        .create_item(authorized(
            &token,
            CreateItemRequest {
                title: "Overflow".into(),
                description: String::new(),
            },
        ))
        .await
        .expect_err("store is full");
    assert_eq!(error.code(), Code::ResourceExhausted);
    server.abort();
    key_server.abort();
}

#[tokio::test]
async fn runnable_server_reports_standard_grpc_health() {
    let (issuer, jwks_url, _signing_key, key_server) = start_identity_provider().await;
    let reserved = std::net::TcpListener::bind("127.0.0.1:0").expect("reserve isolated address");
    let address = reserved.local_addr().expect("reserved address");
    drop(reserved);
    let mut command = Command::new(env!("CARGO_BIN_EXE_kankal-grpc"));
    command
        .env_clear()
        .env("KANKAL_ADDR", address.to_string())
        .env("KANKAL_OIDC_ISSUER", &issuer)
        .env("KANKAL_OIDC_AUDIENCE", "kankal-test")
        .env("KANKAL_OIDC_JWKS_URL", &jwks_url)
        .env("KANKAL_ALLOWED_SUBJECTS", "test-service")
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    let database_url = std::env::var("KANKAL_TEST_DATABASE_URL").ok();
    if let Some(url) = &database_url {
        command.env("KANKAL_DATABASE_URL", url);
    }
    let child = command.spawn().expect("run isolated server");
    let _child = ChildGuard(child);

    let channel = tokio::time::timeout(std::time::Duration::from_secs(10), async {
        loop {
            if let Ok(channel) = tonic::transport::Channel::from_shared(format!("http://{address}"))
                .expect("health URI")
                .connect()
                .await
            {
                break channel;
            }
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }
    })
    .await
    .expect("server started");
    let mut health = HealthClient::new(channel.clone());
    let response = health
        .check(HealthCheckRequest {
            service: "kankal.items.v1.ItemsService".into(),
        })
        .await
        .expect("health response")
        .into_inner();
    assert_eq!(
        response.status,
        tonic_health::pb::health_check_response::ServingStatus::Serving as i32
    );
    if database_url.is_some() {
        let response = health
            .check(HealthCheckRequest {
                service: "kankal.workspace.v1.WorkspaceService".into(),
            })
            .await
            .expect("workspace health")
            .into_inner();
        assert_eq!(
            response.status,
            tonic_health::pb::health_check_response::ServingStatus::Serving as i32
        );
    }
    let mut reflection = ServerReflectionClient::new(channel);
    let request = ServerReflectionRequest {
        host: String::new(),
        message_request: Some(MessageRequest::ListServices(String::new())),
    };
    let mut responses = reflection
        .server_reflection_info(tokio_stream::iter([request]))
        .await
        .expect("reflection call")
        .into_inner();
    let reflected = responses
        .message()
        .await
        .expect("reflection response")
        .expect("service list");
    let Some(MessageResponse::ListServicesResponse(services)) = reflected.message_response else {
        panic!("reflection did not list services");
    };
    assert!(
        services
            .service
            .iter()
            .any(|service| service.name == "kankal.items.v1.ItemsService")
    );
    key_server.abort();
}

#[cfg(unix)]
#[tokio::test]
async fn configured_telemetry_exports_rpc_trace_and_duration() {
    let (events_tx, mut events_rx) = tokio::sync::mpsc::unbounded_channel();
    let collector = TelemetryCollector { events: events_tx };
    let collector_listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .expect("isolated collector");
    let collector_address = collector_listener.local_addr().expect("collector address");
    let collector_task = tokio::spawn(async move {
        tonic::transport::Server::builder()
            .add_service(TraceServiceServer::new(collector.clone()))
            .add_service(MetricsServiceServer::new(collector))
            .serve_with_incoming(tokio_stream::wrappers::TcpListenerStream::new(
                collector_listener,
            ))
            .await
            .expect("test collector");
    });
    let (issuer, jwks_url, signing_key, key_server) = start_identity_provider().await;
    let token = signed_token(&signing_key, &issuer, "kankal-test", "test-service", 3600);
    let reserved = std::net::TcpListener::bind("127.0.0.1:0").expect("reserve app address");
    let address = reserved.local_addr().expect("app address");
    drop(reserved);
    let child = Command::new(env!("CARGO_BIN_EXE_kankal-grpc"))
        .env_clear()
        .env("KANKAL_ADDR", address.to_string())
        .env("KANKAL_OIDC_ISSUER", &issuer)
        .env("KANKAL_OIDC_AUDIENCE", "kankal-test")
        .env("KANKAL_OIDC_JWKS_URL", &jwks_url)
        .env("KANKAL_ALLOWED_SUBJECTS", "test-service")
        .env(
            "OTEL_EXPORTER_OTLP_ENDPOINT",
            format!("http://{collector_address}"),
        )
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("run app with telemetry");
    let mut child = ChildGuard(child);
    let channel = tokio::time::timeout(std::time::Duration::from_secs(10), async {
        loop {
            if let Ok(channel) = tonic::transport::Channel::from_shared(format!("http://{address}"))
                .expect("app URI")
                .connect()
                .await
            {
                break channel;
            }
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }
    })
    .await
    .expect("telemetry app started");
    let mut client = ItemsServiceClient::new(channel);
    client
        .list_items(authorized(&token, ListItemsRequest {}))
        .await
        .expect("traced RPC");

    let status = Command::new("kill")
        .arg("-TERM")
        .arg(child.0.id().to_string())
        .status()
        .expect("stop app");
    assert!(status.success());
    tokio::time::timeout(std::time::Duration::from_secs(12), async {
        loop {
            if let Some(status) = child.0.try_wait().expect("app status") {
                assert!(status.success());
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }
    })
    .await
    .expect("app stopped gracefully");

    let mut trace = false;
    let mut metric = false;
    tokio::time::timeout(std::time::Duration::from_secs(5), async {
        while !(trace && metric) {
            match events_rx.recv().await.expect("collector event") {
                "trace" => trace = true,
                "metric" => metric = true,
                _ => {}
            }
        }
    })
    .await
    .expect("trace and duration exported");
    key_server.abort();
    collector_task.abort();
}

#[cfg(unix)]
#[derive(Clone)]
struct TelemetryCollector {
    events: tokio::sync::mpsc::UnboundedSender<&'static str>,
}

#[cfg(unix)]
#[tonic::async_trait]
impl TraceService for TelemetryCollector {
    async fn export(
        &self,
        request: Request<ExportTraceServiceRequest>,
    ) -> Result<tonic::Response<ExportTraceServiceResponse>, tonic::Status> {
        let has_call = request
            .into_inner()
            .resource_spans
            .iter()
            .flat_map(|resource| &resource.scope_spans)
            .flat_map(|scope| &scope.spans)
            .any(|span| span.name == "grpc.list_items");
        if has_call {
            self.events.send("trace").expect("trace receiver");
        }
        Ok(tonic::Response::new(ExportTraceServiceResponse::default()))
    }
}

#[cfg(unix)]
#[tonic::async_trait]
impl MetricsService for TelemetryCollector {
    async fn export(
        &self,
        request: Request<ExportMetricsServiceRequest>,
    ) -> Result<tonic::Response<ExportMetricsServiceResponse>, tonic::Status> {
        let has_duration = request
            .into_inner()
            .resource_metrics
            .iter()
            .flat_map(|resource| &resource.scope_metrics)
            .flat_map(|scope| &scope.metrics)
            .any(|metric| metric.name == "grpc.server.call.duration");
        if has_duration {
            self.events.send("metric").expect("metric receiver");
        }
        Ok(tonic::Response::new(ExportMetricsServiceResponse::default()))
    }
}

#[test]
fn public_listener_requires_tls_configuration() {
    let output = Command::new(env!("CARGO_BIN_EXE_kankal-grpc"))
        .env_clear()
        .env("KANKAL_ADDR", "0.0.0.0:0")
        .env("KANKAL_OIDC_ISSUER", "https://identity.example.com/")
        .env("KANKAL_OIDC_AUDIENCE", "kankal-test")
        .env("KANKAL_OIDC_JWKS_URL", "https://identity.example.com/jwks")
        .env("KANKAL_ALLOWED_SUBJECTS", "test-service")
        .output()
        .expect("run server without TLS");
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("TLS is required outside loopback"));
}

struct ChildGuard(Child);

impl Drop for ChildGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn authorized<T>(token: &str, message: T) -> Request<T> {
    let mut request = Request::new(message);
    request.metadata_mut().insert(
        "authorization",
        format!("Bearer {token}").parse().expect("token metadata"),
    );
    request
}

async fn start_app(
    issuer: &str,
    jwks_url: &str,
) -> (
    ItemsServiceClient<tonic::transport::Channel>,
    tokio::task::JoinHandle<()>,
) {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .expect("isolated listener");
    let address = listener.local_addr().expect("listener address");
    let auth = Authenticator::new(
        AuthConfig::new(issuer, "kankal-test", jwks_url, ["test-service"])
            .expect("test auth config"),
    )
    .expect("test authenticator");
    let server = tokio::spawn(async move {
        tonic::transport::Server::builder()
            .add_service(item_service(auth))
            .serve_with_incoming(tokio_stream::wrappers::TcpListenerStream::new(listener))
            .await
            .expect("test server");
    });

    let client = ItemsServiceClient::connect(format!("http://{address}"))
        .await
        .expect("test client");
    (client, server)
}

async fn start_identity_provider() -> (String, String, EncodingKey, tokio::task::JoinHandle<()>) {
    let private = RsaPrivateKey::new(&mut rand::rngs::OsRng, 2048).expect("test RSA key");
    let private_der = private.to_pkcs1_der().expect("test key DER");
    let signing_key = EncodingKey::from_rsa_der(private_der.as_bytes());
    let mut jwk = Jwk::from_encoding_key(&signing_key, Algorithm::RS256).expect("public JWK");
    jwk.common.key_id = Some("test-key".to_owned());
    let body = serde_json::to_string(&serde_json::json!({"keys": [jwk]})).expect("JWKS JSON");
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .expect("isolated JWKS listener");
    let address = listener.local_addr().expect("JWKS address");
    let issuer = format!("http://{address}/issuer");
    let jwks_url = format!("http://{address}/jwks");
    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    let server = tokio::spawn(async move {
        loop {
            let (mut stream, _) = listener.accept().await.expect("JWKS connection");
            let mut request = [0u8; 1];
            stream.read_exact(&mut request).await.expect("JWKS request");
            stream
                .write_all(response.as_bytes())
                .await
                .expect("JWKS response");
        }
    });
    (issuer, jwks_url, signing_key, server)
}

fn signed_token(
    key: &EncodingKey,
    issuer: &str,
    audience: &str,
    subject: &str,
    expires_in: i64,
) -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("clock")
        .as_secs() as i64;
    let mut header = Header::new(Algorithm::RS256);
    header.kid = Some("test-key".to_owned());
    encode(&header, &serde_json::json!({"iss": issuer, "aud": audience, "sub": subject, "exp": now + expires_in}), key).expect("test token")
}
