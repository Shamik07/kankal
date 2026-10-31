# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.26.8-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY *.go ./
COPY docs ./docs
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -mod=readonly -trimpath -ldflags="-s -w" -o /out/kankal-go .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build --chown=nonroot:nonroot /out/kankal-go /kankal-go
ENV KANKAL_ADDR=0.0.0.0:8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/kankal-go"]
