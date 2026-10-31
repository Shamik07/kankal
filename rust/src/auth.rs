use std::collections::{HashMap, HashSet};
use std::net::IpAddr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use reqwest::Url;
use serde::Deserialize;
use tokio::sync::Mutex;
use tonic::{Status, metadata::MetadataMap};

const KEY_CACHE_AGE: Duration = Duration::from_secs(300);
const MAX_JWKS_BYTES: usize = 64 * 1024;
const MAX_TOKEN_BYTES: usize = 8 * 1024;
const INVALID_TOKEN: &str = "valid service token required";

pub struct AuthConfig {
    issuer: String,
    audience: String,
    jwks_url: Url,
    allowed_subjects: HashSet<String>,
}

impl AuthConfig {
    pub fn new(
        issuer: &str,
        audience: &str,
        jwks_url: &str,
        allowed_subjects: impl IntoIterator<Item = impl AsRef<str>>,
    ) -> Result<Self, &'static str> {
        let issuer_url = Url::parse(issuer).map_err(|_| "invalid OIDC issuer")?;
        let key_url = Url::parse(jwks_url).map_err(|_| "invalid JWKS URL")?;
        if !secure_url(&issuer_url) || !secure_url(&key_url) {
            return Err("OIDC URLs must use HTTPS outside loopback");
        }
        if audience.trim().is_empty() || issuer.trim().is_empty() {
            return Err("OIDC issuer and audience are required");
        }
        let allowed_subjects: HashSet<String> = allowed_subjects
            .into_iter()
            .map(|subject| subject.as_ref().trim().to_owned())
            .filter(|subject| !subject.is_empty())
            .collect();
        if allowed_subjects.is_empty() {
            return Err("at least one allowed service subject is required");
        }
        Ok(Self {
            issuer: issuer.to_owned(),
            audience: audience.to_owned(),
            jwks_url: key_url,
            allowed_subjects,
        })
    }
}

fn secure_url(url: &Url) -> bool {
    if url.scheme() == "https" {
        return true;
    }
    if url.scheme() != "http" {
        return false;
    }
    match url.host_str() {
        Some("localhost") => true,
        Some(host) => host.parse::<IpAddr>().is_ok_and(|ip| ip.is_loopback()),
        None => false,
    }
}

struct CachedKeys {
    keys: HashMap<String, DecodingKey>,
    expires_at: Instant,
}

#[derive(Clone)]
pub struct Authenticator {
    config: Arc<AuthConfig>,
    client: reqwest::Client,
    cache: Arc<Mutex<Option<CachedKeys>>>,
}

impl Authenticator {
    pub fn new(config: AuthConfig) -> Result<Self, &'static str> {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(3))
            .redirect(reqwest::redirect::Policy::none())
            .build()
            .map_err(|_| "cannot create identity key client")?;
        Ok(Self {
            config: Arc::new(config),
            client,
            cache: Arc::new(Mutex::new(None)),
        })
    }

    pub async fn verify(&self, metadata: &MetadataMap) -> Result<(), Status> {
        let token = metadata
            .get("authorization")
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .filter(|value| !value.is_empty() && value.len() <= MAX_TOKEN_BYTES)
            .ok_or_else(|| Status::unauthenticated(INVALID_TOKEN))?;
        let header = decode_header(token).map_err(|_| Status::unauthenticated(INVALID_TOKEN))?;
        if header.alg != Algorithm::RS256 {
            return Err(Status::unauthenticated(INVALID_TOKEN));
        }
        let kid = header
            .kid
            .filter(|kid| !kid.is_empty())
            .ok_or_else(|| Status::unauthenticated(INVALID_TOKEN))?;

        let key = {
            let mut cache = self.cache.lock().await;
            if cache
                .as_ref()
                .is_none_or(|keys| keys.expires_at <= Instant::now())
            {
                *cache = Some(self.fetch_keys().await?);
            }
            cache.as_ref().and_then(|keys| keys.keys.get(&kid)).cloned()
        };
        let key = key.ok_or_else(|| Status::unauthenticated(INVALID_TOKEN))?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[&self.config.issuer]);
        validation.set_audience(&[&self.config.audience]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);
        validation.leeway = 30;
        validation.validate_nbf = true;
        let claims = decode::<Claims>(token, &key, &validation)
            .map_err(|_| Status::unauthenticated(INVALID_TOKEN))?
            .claims;
        if !self.config.allowed_subjects.contains(&claims.sub) {
            return Err(Status::permission_denied("service is not allowed"));
        }
        Ok(())
    }

    pub async fn refresh(&self) -> Result<(), Status> {
        let keys = self.fetch_keys().await?;
        *self.cache.lock().await = Some(keys);
        Ok(())
    }

    pub async fn ready(&self) -> bool {
        self.cache
            .lock()
            .await
            .as_ref()
            .is_some_and(|keys| keys.expires_at > Instant::now())
    }

    async fn fetch_keys(&self) -> Result<CachedKeys, Status> {
        let mut response = self
            .client
            .get(self.config.jwks_url.clone())
            .send()
            .await
            .map_err(|_| Status::unavailable("identity keys unavailable"))?;
        if !response.status().is_success() {
            return Err(Status::unavailable("identity keys unavailable"));
        }
        let mut body = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| Status::unavailable("identity keys unavailable"))?
        {
            if body.len() + chunk.len() > MAX_JWKS_BYTES {
                return Err(Status::unavailable("identity keys unavailable"));
            }
            body.extend_from_slice(&chunk);
        }
        let jwks: JwkSet = serde_json::from_slice(&body)
            .map_err(|_| Status::unavailable("identity keys unavailable"))?;
        if jwks.keys.is_empty() || jwks.keys.len() > 32 {
            return Err(Status::unavailable("identity keys unavailable"));
        }
        let mut keys = HashMap::new();
        for jwk in jwks.keys {
            let Some(kid) = jwk.common.key_id.as_ref() else {
                continue;
            };
            let key = DecodingKey::from_jwk(&jwk)
                .map_err(|_| Status::unavailable("identity keys unavailable"))?;
            if keys.insert(kid.clone(), key).is_some() {
                return Err(Status::unavailable("identity keys unavailable"));
            }
        }
        if keys.is_empty() {
            return Err(Status::unavailable("identity keys unavailable"));
        }
        Ok(CachedKeys {
            keys,
            expires_at: Instant::now() + KEY_CACHE_AGE,
        })
    }
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
}
