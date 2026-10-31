use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::SaltString};
use rand::{RngCore, rngs::OsRng};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use tonic::{Request, Response, Status};

use crate::workspace_proto::workspace_service_server::WorkspaceService;
use crate::workspace_proto::{
    CreateItemRequest, CreateItemResponse, DeleteItemRequest, DeleteItemResponse,
    GetSessionRequest, GetSessionResponse, Item, ListItemsRequest, ListItemsResponse, Session,
    SignInRequest, SignInResponse, SignOutRequest, SignOutResponse, UpdateItemRequest,
    UpdateItemResponse,
};

#[derive(Clone, Copy)]
pub enum CookieSecurity {
    Secure,
    LocalHttp,
}

#[derive(Clone)]
pub struct Workspace {
    pool: PgPool,
    secure_cookie: bool,
    attempts: Arc<Mutex<Attempts>>,
    dummy_hash: Arc<str>,
}

#[derive(Default)]
struct Attempts {
    by_email: HashMap<String, Vec<Instant>>,
    global: Vec<Instant>,
}

pub async fn create_account(
    pool: &PgPool,
    email: &str,
    password: &str,
) -> Result<(), &'static str> {
    let email = email.trim().to_lowercase();
    if email.is_empty()
        || email.len() > 254
        || !email.contains('@')
        || password.len() < 12
        || password.len() > 1024
    {
        return Err("invalid account details");
    }
    let password = password.to_owned();
    let hash = tokio::task::spawn_blocking(move || {
        Argon2::default()
            .hash_password(password.as_bytes(), &SaltString::generate(&mut OsRng))
            .map(|h| h.to_string())
    })
    .await
    .map_err(|_| "password hashing failed")?
    .map_err(|_| "password hashing failed")?;
    sqlx::query("INSERT INTO workspace_users (email, password_hash) VALUES ($1, $2)")
        .bind(email)
        .bind(hash)
        .execute(pool)
        .await
        .map_err(|_| "account creation failed")?;
    Ok(())
}

impl Workspace {
    pub fn new(pool: PgPool, cookie_security: CookieSecurity) -> Self {
        let dummy_hash = Argon2::default()
            .hash_password(b"invalid-password", &SaltString::generate(&mut OsRng))
            .expect("valid password hashing parameters")
            .to_string();
        Self {
            pool,
            secure_cookie: matches!(cookie_security, CookieSecurity::Secure),
            attempts: Arc::new(Mutex::new(Attempts::default())),
            dummy_hash: dummy_hash.into(),
        }
    }

    fn cookie(&self, value: &str, max_age: u32) -> String {
        format!(
            "kankal_session={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={max_age}{}",
            if self.secure_cookie { "; Secure" } else { "" }
        )
    }

    fn token<T>(request: &Request<T>) -> Option<Vec<u8>> {
        let cookie = request.metadata().get("cookie")?.to_str().ok()?;
        let token = cookie
            .split(';')
            .map(str::trim)
            .find_map(|part| part.strip_prefix("kankal_session="))?;
        let bytes = hex::decode(token).ok()?;
        if bytes.len() != 32 {
            return None;
        }
        Some(Sha256::digest(bytes).to_vec())
    }

    async fn user<T>(&self, request: &Request<T>) -> Result<(i64, String), Status> {
        let hash =
            Self::token(request).ok_or_else(|| Status::unauthenticated("sign in required"))?;
        sqlx::query_as::<_, (i64, String)>("SELECT u.id, u.email FROM workspace_sessions s JOIN workspace_users u ON u.id = s.user_id WHERE s.token_hash = $1 AND s.expires_at > now()")
            .bind(hash).fetch_optional(&self.pool).await.map_err(db_error)?
            .ok_or_else(|| Status::unauthenticated("sign in required"))
    }

    fn allow_attempt(&self, email: &str) -> Result<(), Status> {
        let mut attempts = self
            .attempts
            .lock()
            .map_err(|_| Status::unavailable("sign in unavailable"))?;
        let now = Instant::now();
        attempts
            .global
            .retain(|time| now.duration_since(*time) < Duration::from_secs(60));
        if attempts.global.len() >= 20 {
            return Err(Status::resource_exhausted("try again later"));
        }
        attempts.by_email.retain(|_, times| {
            times.retain(|time| now.duration_since(*time) < Duration::from_secs(900));
            !times.is_empty()
        });
        if attempts.by_email.len() >= 10_000 && !attempts.by_email.contains_key(email) {
            return Err(Status::resource_exhausted("try again later"));
        }
        let times = attempts.by_email.entry(email.to_owned()).or_default();
        if times.len() >= 5 {
            return Err(Status::resource_exhausted("try again later"));
        }
        times.push(now);
        attempts.global.push(now);
        Ok(())
    }
}

fn db_error(_: sqlx::Error) -> Status {
    Status::unavailable("workspace unavailable")
}
fn valid_item(title: &str, description: &str) -> bool {
    !title.trim().is_empty() && title.chars().count() <= 200 && description.chars().count() <= 2000
}
fn item(row: sqlx::postgres::PgRow) -> Item {
    Item {
        id: row.get::<i64, _>("id").to_string(),
        title: row.get("title"),
        description: row.get("description"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    }
}
fn item_id(value: &str) -> Result<i64, Status> {
    value
        .parse::<i64>()
        .ok()
        .filter(|id| *id > 0)
        .ok_or_else(|| Status::invalid_argument("invalid item id"))
}
const ITEM_FIELDS: &str = r#"id, title, description, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS created_at, to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS updated_at"#;

#[tonic::async_trait]
impl WorkspaceService for Workspace {
    async fn sign_in(
        &self,
        request: Request<SignInRequest>,
    ) -> Result<Response<SignInResponse>, Status> {
        let input = request.into_inner();
        let email = input.email.trim().to_lowercase();
        if email.len() > 254 || input.password.len() > 1024 {
            tracing::warn!(outcome = "workspace_sign_in_failed");
            return Err(Status::unauthenticated("invalid credentials"));
        }
        self.allow_attempt(&email).inspect_err(|_| {
            tracing::warn!(outcome = "workspace_sign_in_limited");
        })?;
        let found = sqlx::query_as::<_, (i64, String)>(
            "SELECT id, password_hash FROM workspace_users WHERE email = $1",
        )
        .bind(&email)
        .fetch_optional(&self.pool)
        .await
        .map_err(db_error)?;
        let hash = found
            .as_ref()
            .map_or_else(|| self.dummy_hash.to_string(), |(_, hash)| hash.clone());
        let valid = tokio::task::spawn_blocking(move || {
            PasswordHash::new(&hash).ok().is_some_and(|hash| {
                Argon2::default()
                    .verify_password(input.password.as_bytes(), &hash)
                    .is_ok()
            })
        })
        .await
        .map_err(|_| Status::unavailable("sign in unavailable"))?;
        let (id, _) = found.filter(|_| valid).ok_or_else(|| {
            tracing::warn!(outcome = "workspace_sign_in_failed");
            Status::unauthenticated("invalid credentials")
        })?;
        self.attempts
            .lock()
            .map_err(|_| Status::unavailable("sign in unavailable"))?
            .by_email
            .remove(&email);
        let mut token = [0_u8; 32];
        OsRng.fill_bytes(&mut token);
        let hash = Sha256::digest(token).to_vec();
        sqlx::query("INSERT INTO workspace_sessions (token_hash, user_id, expires_at) VALUES ($1, $2, now() + interval '7 days')")
            .bind(hash).bind(id).execute(&self.pool).await.map_err(db_error)?;
        let mut response = Response::new(SignInResponse {
            session: Some(Session {
                id: id.to_string(),
                email,
            }),
        });
        response.metadata_mut().insert(
            "set-cookie",
            self.cookie(&hex::encode(token), 604800)
                .parse()
                .map_err(|_| Status::internal("session unavailable"))?,
        );
        Ok(response)
    }

    async fn get_session(
        &self,
        request: Request<GetSessionRequest>,
    ) -> Result<Response<GetSessionResponse>, Status> {
        let (id, email) = self.user(&request).await?;
        Ok(Response::new(GetSessionResponse {
            session: Some(Session {
                id: id.to_string(),
                email,
            }),
        }))
    }

    async fn sign_out(
        &self,
        request: Request<SignOutRequest>,
    ) -> Result<Response<SignOutResponse>, Status> {
        let hash =
            Self::token(&request).ok_or_else(|| Status::unauthenticated("sign in required"))?;
        sqlx::query("DELETE FROM workspace_sessions WHERE token_hash = $1")
            .bind(hash)
            .execute(&self.pool)
            .await
            .map_err(db_error)?;
        let mut response = Response::new(SignOutResponse {});
        response.metadata_mut().insert(
            "set-cookie",
            self.cookie("", 0)
                .parse()
                .map_err(|_| Status::internal("session unavailable"))?,
        );
        Ok(response)
    }

    async fn list_items(
        &self,
        request: Request<ListItemsRequest>,
    ) -> Result<Response<ListItemsResponse>, Status> {
        let (user_id, _) = self.user(&request).await?;
        let rows = sqlx::query(&format!(
            "SELECT {ITEM_FIELDS} FROM workspace_items WHERE user_id = $1 ORDER BY id"
        ))
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(db_error)?;
        Ok(Response::new(ListItemsResponse {
            items: rows.into_iter().map(item).collect(),
        }))
    }

    async fn create_item(
        &self,
        request: Request<CreateItemRequest>,
    ) -> Result<Response<CreateItemResponse>, Status> {
        let (user_id, _) = self.user(&request).await?;
        let input = request.into_inner();
        if !valid_item(&input.title, &input.description) {
            return Err(Status::invalid_argument("invalid item fields"));
        }
        let row = sqlx::query(&format!("INSERT INTO workspace_items (user_id, title, description) VALUES ($1, $2, $3) RETURNING {ITEM_FIELDS}"))
            .bind(user_id).bind(input.title.trim()).bind(input.description.trim()).fetch_one(&self.pool).await.map_err(db_error)?;
        Ok(Response::new(CreateItemResponse {
            item: Some(item(row)),
        }))
    }

    async fn update_item(
        &self,
        request: Request<UpdateItemRequest>,
    ) -> Result<Response<UpdateItemResponse>, Status> {
        let (user_id, _) = self.user(&request).await?;
        let input = request.into_inner();
        if !valid_item(&input.title, &input.description) {
            return Err(Status::invalid_argument("invalid item fields"));
        }
        let row = sqlx::query(&format!("UPDATE workspace_items SET title = $3, description = $4, updated_at = now() WHERE user_id = $1 AND id = $2 RETURNING {ITEM_FIELDS}"))
            .bind(user_id).bind(item_id(&input.id)?).bind(input.title.trim()).bind(input.description.trim()).fetch_optional(&self.pool).await.map_err(db_error)?
            .ok_or_else(|| Status::not_found("item not found"))?;
        Ok(Response::new(UpdateItemResponse {
            item: Some(item(row)),
        }))
    }

    async fn delete_item(
        &self,
        request: Request<DeleteItemRequest>,
    ) -> Result<Response<DeleteItemResponse>, Status> {
        let (user_id, _) = self.user(&request).await?;
        let id = item_id(&request.into_inner().id)?;
        let result = sqlx::query("DELETE FROM workspace_items WHERE user_id = $1 AND id = $2")
            .bind(user_id)
            .bind(id)
            .execute(&self.pool)
            .await
            .map_err(db_error)?;
        if result.rows_affected() == 0 {
            return Err(Status::not_found("item not found"));
        }
        Ok(Response::new(DeleteItemResponse {}))
    }
}
