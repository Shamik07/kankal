fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=migrations");
    let mut config = prost_build::Config::new();
    config.protoc_executable(protoc_bin_vendored::protoc_bin_path()?);
    tonic_prost_build::configure()
        .file_descriptor_set_path(std::env::var("OUT_DIR")? + "/kankal_descriptor.bin")
        .compile_with_config(
            config,
            &[
                "proto/kankal/items/v1/items.proto",
                "proto/kankal/workspace/v1/workspace.proto",
            ],
            &["proto"],
        )?;
    Ok(())
}
