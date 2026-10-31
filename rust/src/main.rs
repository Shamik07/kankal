use std::env;
use std::net::SocketAddr;
use std::time::Duration;

use kankal_grpc::auth::{AuthConfig, Authenticator};
use kankal_grpc::proto::items_service_server::ItemsServiceServer;
use kankal_grpc::workspace::{CookieSecurity, Workspace};
use kankal_grpc::workspace_proto::workspace_service_server::WorkspaceServiceServer;
use kankal_grpc::{ItemHandler, item_service};
use tonic::transport::{Identity, Server, ServerTlsConfig};
use tonic_health::ServingStatus;

mod observability;

const DESCRIPTOR: &[u8] = tonic::include_file_descriptor_set!("kankal_descriptor");

struct Config {
    address: SocketAddr,
    auth: Option<AuthConfig>,
    database_url: Option<String>,
    secure_cookie: bool,
    tls_identity: Option<Identity>,
}

impl Config {
    fn from_env() -> Result<Self, &'static str> {
        let address = env::var("KANKAL_ADDR")
            .unwrap_or_else(|_| "127.0.0.1:50051".to_owned())
            .parse::<SocketAddr>()
            .map_err(|_| "invalid KANKAL_ADDR")?;
        let database_url = env::var("KANKAL_DATABASE_URL").ok();
        let identity_settings = [
            "KANKAL_OIDC_ISSUER",
            "KANKAL_OIDC_AUDIENCE",
            "KANKAL_OIDC_JWKS_URL",
            "KANKAL_ALLOWED_SUBJECTS",
        ];
        let auth = if database_url.is_some()
            && identity_settings
                .iter()
                .all(|key| env::var_os(key).is_none())
        {
            None
        } else {
            let issuer =
                env::var("KANKAL_OIDC_ISSUER").map_err(|_| "KANKAL_OIDC_ISSUER is required")?;
            let audience =
                env::var("KANKAL_OIDC_AUDIENCE").map_err(|_| "KANKAL_OIDC_AUDIENCE is required")?;
            let jwks_url =
                env::var("KANKAL_OIDC_JWKS_URL").map_err(|_| "KANKAL_OIDC_JWKS_URL is required")?;
            let subjects = env::var("KANKAL_ALLOWED_SUBJECTS")
                .map_err(|_| "KANKAL_ALLOWED_SUBJECTS is required")?;
            Some(AuthConfig::new(
                &issuer,
                &audience,
                &jwks_url,
                subjects.split(','),
            )?)
        };

        let tls_identity = match (
            env::var("KANKAL_TLS_CERT_PATH"),
            env::var("KANKAL_TLS_KEY_PATH"),
        ) {
            (Ok(cert_path), Ok(key_path)) => {
                let cert = std::fs::read(cert_path).map_err(|_| "cannot read TLS certificate")?;
                let key = std::fs::read(key_path).map_err(|_| "cannot read TLS private key")?;
                Some(Identity::from_pem(cert, key))
            }
            (Err(_), Err(_)) => None,
            _ => return Err("both TLS certificate and key paths are required"),
        };
        if !address.ip().is_loopback() && tls_identity.is_none() {
            return Err("TLS is required outside loopback");
        }
        let secure_cookie = match env::var("KANKAL_SECURE_COOKIES").as_deref() {
            Ok("true") => true,
            Ok("false") if address.ip().is_loopback() && tls_identity.is_none() => false,
            Ok(_) => return Err("invalid KANKAL_SECURE_COOKIES"),
            Err(env::VarError::NotPresent) => !address.ip().is_loopback() || tls_identity.is_some(),
            Err(_) => return Err("invalid KANKAL_SECURE_COOKIES"),
        };
        Ok(Self {
            address,
            auth,
            database_url,
            secure_cookie,
            tls_identity,
        })
    }
}

#[tokio::main]
async fn main() {
    let telemetry = match observability::init() {
        Ok(telemetry) => telemetry,
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(1);
        }
    };
    let result = run().await;
    if let Err(message) = result {
        tracing::error!(outcome = message);
    }
    telemetry.shutdown();
    if result.is_err() {
        std::process::exit(1);
    }
}

async fn run() -> Result<(), &'static str> {
    let config = Config::from_env()?;
    let auth = match config.auth {
        Some(auth) => {
            let auth = Authenticator::new(auth)?;
            auth.refresh()
                .await
                .map_err(|_| "cannot load identity keys")?;
            Some(auth)
        }
        None => None,
    };
    let items = auth.clone().map(item_service);
    let workspace_pool = if let Some(url) = config.database_url {
        let pool = sqlx::PgPool::connect(&url)
            .await
            .map_err(|_| "database connection failed")?;
        sqlx::migrate!()
            .run(&pool)
            .await
            .map_err(|_| "database migration failed")?;
        Some(pool)
    } else {
        None
    };
    let workspace = workspace_pool.clone().map(|pool| {
        WorkspaceServiceServer::new(Workspace::new(
            pool,
            if config.secure_cookie {
                CookieSecurity::Secure
            } else {
                CookieSecurity::LocalHttp
            },
        ))
        .max_decoding_message_size(16 * 1024)
    });
    let (reporter, health) = tonic_health::server::health_reporter();
    if items.is_some() {
        reporter
            .set_serving::<ItemsServiceServer<ItemHandler>>()
            .await;
    }
    if workspace.is_some() {
        reporter
            .set_serving::<WorkspaceServiceServer<Workspace>>()
            .await;
    }
    let refresh_auth = auth.clone();
    let refresh_task = tokio::spawn(async move {
        let mut interval = tokio::time::interval_at(
            tokio::time::Instant::now() + Duration::from_secs(60),
            Duration::from_secs(60),
        );
        loop {
            interval.tick().await;
            let Some(refresh_auth) = &refresh_auth else {
                continue;
            };
            if refresh_auth.refresh().await.is_err() {
                tracing::warn!(outcome = "identity_key_refresh_failed");
            }
        }
    });
    let health_reporter = reporter.clone();
    let health_auth = auth.clone();
    let health_task = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(2));
        loop {
            interval.tick().await;
            let auth_ready = match &health_auth {
                Some(auth) => auth.ready().await,
                None => true,
            };
            let workspace_ready = match &workspace_pool {
                Some(pool) => matches!(
                    tokio::time::timeout(
                        Duration::from_secs(1),
                        sqlx::query("SELECT 1").execute(pool)
                    )
                    .await,
                    Ok(Ok(_))
                ),
                None => true,
            };
            let status = |ready| {
                if ready {
                    ServingStatus::Serving
                } else {
                    ServingStatus::NotServing
                }
            };
            if health_auth.is_some() {
                health_reporter
                    .set_service_status("kankal.items.v1.ItemsService", status(auth_ready))
                    .await;
            }
            if workspace_pool.is_some() {
                health_reporter
                    .set_service_status(
                        "kankal.workspace.v1.WorkspaceService",
                        status(workspace_ready),
                    )
                    .await;
            }
            health_reporter
                .set_service_status("", status(auth_ready && workspace_ready))
                .await;
        }
    });
    let reflection = tonic_reflection::server::Builder::configure()
        .register_encoded_file_descriptor_set(DESCRIPTOR)
        .build_v1()
        .map_err(|_| "cannot start gRPC reflection")?;

    let mut server = Server::builder()
        .accept_http1(true)
        .layer(tonic_web::GrpcWebLayer::new())
        .timeout(Duration::from_secs(10))
        .concurrency_limit_per_connection(64);
    if let Some(identity) = config.tls_identity {
        server = server
            .tls_config(ServerTlsConfig::new().identity(identity))
            .map_err(|_| "invalid TLS configuration")?;
    }
    tracing::info!(outcome = "starting");
    let (shutdown_tx, mut shutdown_rx) = tokio::sync::watch::channel(false);
    let stop_health = health_task.abort_handle();
    let mut shutdown_task = tokio::spawn(async move {
        shutdown_signal().await;
        stop_health.abort();
        reporter
            .set_service_status("", ServingStatus::NotServing)
            .await;
        reporter
            .set_not_serving::<ItemsServiceServer<ItemHandler>>()
            .await;
        reporter
            .set_not_serving::<WorkspaceServiceServer<Workspace>>()
            .await;
        tracing::info!(outcome = "stopping");
        let _ = shutdown_tx.send(true);
    });
    let serve = server
        .add_service(health)
        .add_service(reflection)
        .add_optional_service(items)
        .add_optional_service(workspace)
        .serve_with_shutdown(config.address, async move {
            let _ = shutdown_rx.changed().await;
        });
    tokio::pin!(serve);
    let result = tokio::select! {
        result = &mut serve => result.map_err(|_| "gRPC server stopped unexpectedly"),
        _ = &mut shutdown_task => {
            tokio::time::timeout(Duration::from_secs(10), &mut serve)
                .await
                .map_err(|_| "graceful shutdown timed out")
                .and_then(|result| result.map_err(|_| "gRPC server stopped unexpectedly"))
        }
    };
    shutdown_task.abort();
    refresh_task.abort();
    health_task.abort();
    result?;
    tracing::info!(outcome = "stopped");
    Ok(())
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};
        if let Ok(mut terminate) = signal(SignalKind::terminate()) {
            tokio::select! {
                _ = tokio::signal::ctrl_c() => {},
                _ = terminate.recv() => {},
            }
            return;
        }
    }
    let _ = tokio::signal::ctrl_c().await;
}
