use kankal_grpc::workspace::{CookieSecurity, Workspace, create_account};
use kankal_grpc::workspace_proto::workspace_service_server::WorkspaceService;
use kankal_grpc::workspace_proto::{
    CreateItemRequest, DeleteItemRequest, ListItemsRequest, SignInRequest, UpdateItemRequest,
};
use tonic::{Code, Request};

#[tokio::test]
#[ignore = "requires an isolated migrated PostgreSQL database in KANKAL_TEST_DATABASE_URL"]
async fn workspace_access_is_scoped_to_signed_in_users() {
    let database_url = std::env::var("KANKAL_TEST_DATABASE_URL").expect("test database URL");
    let pool = sqlx::PgPool::connect(&database_url)
        .await
        .expect("connect test database");
    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("migrate test database");
    create_account(&pool, "one@example.test", "test-password-one")
        .await
        .expect("create first account");
    create_account(&pool, "two@example.test", "test-password-two")
        .await
        .expect("create second account");
    let service = Workspace::new(pool.clone(), CookieSecurity::LocalHttp);
    for _ in 0..5 {
        let denied = service
            .sign_in(Request::new(SignInRequest {
                email: "missing@example.test".into(),
                password: "wrong-password".into(),
            }))
            .await
            .expect_err("invalid credentials rejected");
        assert_eq!(denied.code(), Code::Unauthenticated);
    }
    let limited = service
        .sign_in(Request::new(SignInRequest {
            email: "missing@example.test".into(),
            password: "wrong-password".into(),
        }))
        .await
        .expect_err("repeated attempts limited");
    assert_eq!(limited.code(), Code::ResourceExhausted);
    let anonymous = service
        .list_items(Request::new(ListItemsRequest {}))
        .await
        .expect_err("anonymous access rejected");
    assert_eq!(anonymous.code(), Code::Unauthenticated);
    let first = service
        .sign_in(Request::new(SignInRequest {
            email: "one@example.test".into(),
            password: "test-password-one".into(),
        }))
        .await
        .expect("first sign in");
    let cookie_header = first
        .metadata()
        .get("set-cookie")
        .expect("session cookie")
        .to_str()
        .expect("ASCII cookie");
    assert!(cookie_header.contains("HttpOnly") && cookie_header.contains("SameSite=Strict"));
    let cookie = first
        .metadata()
        .get("set-cookie")
        .expect("session cookie")
        .to_str()
        .expect("ASCII cookie")
        .split(';')
        .next()
        .expect("cookie value")
        .to_owned();
    let mut create = Request::new(CreateItemRequest {
        title: "Private item".into(),
        description: String::new(),
    });
    create
        .metadata_mut()
        .insert("cookie", cookie.parse().expect("cookie metadata"));
    let created = service
        .create_item(create)
        .await
        .expect("create item")
        .into_inner()
        .item
        .expect("item");
    let second = service
        .sign_in(Request::new(SignInRequest {
            email: "two@example.test".into(),
            password: "test-password-two".into(),
        }))
        .await
        .expect("second sign in");
    let cookie = second
        .metadata()
        .get("set-cookie")
        .expect("session cookie")
        .to_str()
        .expect("ASCII cookie")
        .split(';')
        .next()
        .expect("cookie value")
        .to_owned();
    let mut list = Request::new(ListItemsRequest {});
    list.metadata_mut()
        .insert("cookie", cookie.parse().expect("cookie metadata"));
    assert!(
        service
            .list_items(list)
            .await
            .expect("list items")
            .into_inner()
            .items
            .is_empty()
    );
    let mut update = Request::new(UpdateItemRequest {
        id: created.id.clone(),
        title: "Changed".into(),
        description: String::new(),
    });
    update
        .metadata_mut()
        .insert("cookie", cookie.parse().expect("cookie metadata"));
    assert_eq!(
        service
            .update_item(update)
            .await
            .expect_err("other user cannot update")
            .code(),
        Code::NotFound
    );
    let mut delete = Request::new(DeleteItemRequest { id: created.id });
    delete
        .metadata_mut()
        .insert("cookie", cookie.parse().expect("cookie metadata"));
    assert_eq!(
        service
            .delete_item(delete)
            .await
            .expect_err("other user cannot delete")
            .code(),
        Code::NotFound
    );
    let service = Workspace::new(pool, CookieSecurity::LocalHttp);
    for index in 0..20 {
        let result = service
            .sign_in(Request::new(SignInRequest {
                email: format!("unknown{index}@example.test"),
                password: "wrong-password".into(),
            }))
            .await;
        assert_eq!(
            result.expect_err("invalid credentials").code(),
            Code::Unauthenticated
        );
    }
    let limited = service
        .sign_in(Request::new(SignInRequest {
            email: "another@example.test".into(),
            password: "wrong-password".into(),
        }))
        .await
        .expect_err("global sign-in limit");
    assert_eq!(limited.code(), Code::ResourceExhausted);
}
