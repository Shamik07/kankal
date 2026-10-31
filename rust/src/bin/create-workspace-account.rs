use kankal_grpc::workspace::create_account;

#[tokio::main]
async fn main() {
    if let Err(message) = run().await {
        eprintln!("{message}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), &'static str> {
    let email = std::env::args()
        .nth(1)
        .ok_or("usage: create-workspace-account EMAIL")?;
    let url =
        std::env::var("KANKAL_DATABASE_URL").map_err(|_| "KANKAL_DATABASE_URL is required")?;
    let password = rpassword::prompt_password("Password: ").map_err(|_| "cannot read password")?;
    let confirm =
        rpassword::prompt_password("Confirm password: ").map_err(|_| "cannot read password")?;
    if password != confirm {
        return Err("passwords do not match");
    }
    let pool = sqlx::PgPool::connect(&url)
        .await
        .map_err(|_| "database connection failed")?;
    sqlx::migrate!()
        .run(&pool)
        .await
        .map_err(|_| "database migration failed")?;
    create_account(&pool, &email, &password).await?;
    println!("Account created.");
    Ok(())
}
