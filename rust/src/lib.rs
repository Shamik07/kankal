pub mod auth;
pub mod workspace;

pub mod workspace_proto {
    tonic::include_proto!("kankal.workspace.v1");
}

pub mod proto {
    tonic::include_proto!("kankal.items.v1");
}

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use opentelemetry::KeyValue;
use opentelemetry::metrics::Histogram;
use opentelemetry::propagation::Extractor;
use proto::items_service_server::ItemsService as ItemRpc;
use proto::items_service_server::ItemsServiceServer;
use proto::{
    CreateItemRequest, CreateItemResponse, DeleteItemRequest, DeleteItemResponse, GetItemRequest,
    GetItemResponse, Item, ListItemsRequest, ListItemsResponse, UpdateItemRequest,
    UpdateItemResponse,
};
use tonic::metadata::{KeyRef, MetadataMap};
use tonic::{Code, Request, Response, Status};
use tracing_opentelemetry::OpenTelemetrySpanExt as _;

const MAX_ITEMS: usize = 1_000;

#[derive(Clone)]
pub struct ItemHandler {
    auth: auth::Authenticator,
    store: Arc<Mutex<Store>>,
    duration: Histogram<f64>,
}

pub fn item_service(auth: auth::Authenticator) -> ItemsServiceServer<ItemHandler> {
    ItemsServiceServer::new(ItemHandler::new(auth)).max_decoding_message_size(16 * 1024)
}

#[derive(Default)]
struct Store {
    next_id: u64,
    items: BTreeMap<u64, Item>,
}

impl ItemHandler {
    pub fn new(auth: auth::Authenticator) -> Self {
        Self {
            auth,
            store: Arc::new(Mutex::new(Store::default())),
            duration: opentelemetry::global::meter("kankal-grpc")
                .f64_histogram("grpc.server.call.duration")
                .with_unit("s")
                .build(),
        }
    }

    fn observe<T>(
        &self,
        method: &'static str,
        started: Instant,
        result: &Result<Response<T>, Status>,
    ) {
        let code = result.as_ref().err().map_or(Code::Ok, Status::code);
        tracing::info!(method, status = ?code, outcome = "completed");
        self.duration.record(
            started.elapsed().as_secs_f64(),
            &[
                KeyValue::new("grpc.method", method),
                KeyValue::new("grpc.status", grpc_status_name(code)),
            ],
        );
    }
}

fn grpc_status_name(code: Code) -> &'static str {
    match code {
        Code::Ok => "OK",
        Code::Cancelled => "CANCELLED",
        Code::Unknown => "UNKNOWN",
        Code::InvalidArgument => "INVALID_ARGUMENT",
        Code::DeadlineExceeded => "DEADLINE_EXCEEDED",
        Code::NotFound => "NOT_FOUND",
        Code::AlreadyExists => "ALREADY_EXISTS",
        Code::PermissionDenied => "PERMISSION_DENIED",
        Code::ResourceExhausted => "RESOURCE_EXHAUSTED",
        Code::FailedPrecondition => "FAILED_PRECONDITION",
        Code::Aborted => "ABORTED",
        Code::OutOfRange => "OUT_OF_RANGE",
        Code::Unimplemented => "UNIMPLEMENTED",
        Code::Internal => "INTERNAL",
        Code::Unavailable => "UNAVAILABLE",
        Code::DataLoss => "DATA_LOSS",
        Code::Unauthenticated => "UNAUTHENTICATED",
    }
}

struct TraceMetadata<'a>(&'a MetadataMap);

impl Extractor for TraceMetadata<'_> {
    fn get(&self, key: &str) -> Option<&str> {
        self.0.get(key)?.to_str().ok()
    }

    fn keys(&self) -> Vec<&str> {
        self.0
            .keys()
            .filter_map(|key| match key {
                KeyRef::Ascii(key) => Some(key.as_str()),
                KeyRef::Binary(_) => None,
            })
            .collect()
    }
}

fn start_call(metadata: &MetadataMap) -> Instant {
    opentelemetry::global::get_text_map_propagator(|propagator| {
        let parent = propagator.extract(&TraceMetadata(metadata));
        // No OpenTelemetry layer is expected when export is disabled.
        let _ = tracing::Span::current().set_parent(parent);
    });
    Instant::now()
}

fn valid_item(title: &str, description: &str) -> bool {
    !title.trim().is_empty() && title.chars().count() <= 200 && description.chars().count() <= 2_000
}

#[tonic::async_trait]
impl ItemRpc for ItemHandler {
    #[tracing::instrument(skip_all, name = "grpc.list_items")]
    async fn list_items(
        &self,
        request: Request<ListItemsRequest>,
    ) -> Result<Response<ListItemsResponse>, Status> {
        let started = start_call(request.metadata());
        let result = async {
            self.auth.verify(request.metadata()).await?;
            let store = self
                .store
                .lock()
                .map_err(|_| Status::internal("item store unavailable"))?;
            Ok(Response::new(ListItemsResponse {
                items: store.items.values().cloned().collect(),
            }))
        }
        .await;
        self.observe("kankal.items.v1.ItemsService/ListItems", started, &result);
        result
    }

    #[tracing::instrument(skip_all, name = "grpc.create_item")]
    async fn create_item(
        &self,
        request: Request<CreateItemRequest>,
    ) -> Result<Response<CreateItemResponse>, Status> {
        let started = start_call(request.metadata());
        let result = async {
            self.auth.verify(request.metadata()).await?;
            let input = request.into_inner();
            if !valid_item(&input.title, &input.description) {
                return Err(Status::invalid_argument("invalid item fields"));
            }
            let mut store = self
                .store
                .lock()
                .map_err(|_| Status::internal("item store unavailable"))?;
            if store.items.len() >= MAX_ITEMS {
                return Err(Status::resource_exhausted("item limit reached"));
            }
            store.next_id = store
                .next_id
                .checked_add(1)
                .ok_or_else(|| Status::resource_exhausted("item limit reached"))?;
            let item = Item {
                id: store.next_id,
                title: input.title,
                description: input.description,
            };
            store.items.insert(item.id, item.clone());
            Ok(Response::new(CreateItemResponse { item: Some(item) }))
        }
        .await;
        self.observe("kankal.items.v1.ItemsService/CreateItem", started, &result);
        result
    }

    #[tracing::instrument(skip_all, name = "grpc.get_item")]
    async fn get_item(
        &self,
        request: Request<GetItemRequest>,
    ) -> Result<Response<GetItemResponse>, Status> {
        let started = start_call(request.metadata());
        let result = async {
            self.auth.verify(request.metadata()).await?;
            let id = request.into_inner().id;
            if id == 0 {
                return Err(Status::invalid_argument("item id must be positive"));
            }
            let store = self
                .store
                .lock()
                .map_err(|_| Status::internal("item store unavailable"))?;
            let item = store
                .items
                .get(&id)
                .ok_or_else(|| Status::not_found("item not found"))?;
            Ok(Response::new(GetItemResponse {
                item: Some(item.clone()),
            }))
        }
        .await;
        self.observe("kankal.items.v1.ItemsService/GetItem", started, &result);
        result
    }

    #[tracing::instrument(skip_all, name = "grpc.update_item")]
    async fn update_item(
        &self,
        request: Request<UpdateItemRequest>,
    ) -> Result<Response<UpdateItemResponse>, Status> {
        let started = start_call(request.metadata());
        let result = async {
            self.auth.verify(request.metadata()).await?;
            let input = request.into_inner();
            if input.id == 0 || !valid_item(&input.title, &input.description) {
                return Err(Status::invalid_argument("invalid item fields"));
            }
            let mut store = self
                .store
                .lock()
                .map_err(|_| Status::internal("item store unavailable"))?;
            let item = store
                .items
                .get_mut(&input.id)
                .ok_or_else(|| Status::not_found("item not found"))?;
            item.title = input.title;
            item.description = input.description;
            Ok(Response::new(UpdateItemResponse {
                item: Some(item.clone()),
            }))
        }
        .await;
        self.observe("kankal.items.v1.ItemsService/UpdateItem", started, &result);
        result
    }

    #[tracing::instrument(skip_all, name = "grpc.delete_item")]
    async fn delete_item(
        &self,
        request: Request<DeleteItemRequest>,
    ) -> Result<Response<DeleteItemResponse>, Status> {
        let started = start_call(request.metadata());
        let result = async {
            self.auth.verify(request.metadata()).await?;
            let id = request.into_inner().id;
            if id == 0 {
                return Err(Status::invalid_argument("item id must be positive"));
            }
            let mut store = self
                .store
                .lock()
                .map_err(|_| Status::internal("item store unavailable"))?;
            if store.items.remove(&id).is_none() {
                return Err(Status::not_found("item not found"));
            }
            Ok(Response::new(DeleteItemResponse {}))
        }
        .await;
        self.observe("kankal.items.v1.ItemsService/DeleteItem", started, &result);
        result
    }
}
