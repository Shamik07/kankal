# syntax=docker/dockerfile:1
FROM rust:1.95.0-trixie AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends cmake clang pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY build.rs ./
COPY proto ./proto
COPY migrations ./migrations
COPY src ./src
ENV CARGO_INCREMENTAL=0 CARGO_PROFILE_RELEASE_DEBUG=0 \
    CARGO_PROFILE_RELEASE_STRIP=symbols CARGO_PROFILE_RELEASE_PANIC=abort
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo build --locked --release --bins \
    && install -D target/release/kankal-grpc /out/kankal-grpc \
    && install -D target/release/create-workspace-account /out/create-workspace-account

FROM gcr.io/distroless/base-nossl-debian13:nonroot
COPY --from=build --chown=nonroot:nonroot /out/kankal-grpc /kankal-grpc
COPY --from=build --chown=nonroot:nonroot /out/create-workspace-account /create-workspace-account
WORKDIR /run/tls
ENV KANKAL_ADDR=0.0.0.0:50051
EXPOSE 50051
USER nonroot:nonroot
STOPSIGNAL SIGTERM
ENTRYPOINT ["/kankal-grpc"]
