package main

import (
	"context"
	_ "embed"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
)

//go:embed docs/openapi.json
var openAPISpec []byte

//go:embed docs/index.html
var docsHTML []byte

type Config struct {
	Address     string
	Token       string
	DatabaseURL string
}

func LoadConfig() (Config, error) {
	c := Config{Address: strings.TrimSpace(os.Getenv("KANKAL_ADDR")), Token: os.Getenv("KANKAL_BEARER_TOKEN"), DatabaseURL: os.Getenv("KANKAL_DATABASE_URL")}
	if c.Address == "" {
		c.Address = "127.0.0.1:8080"
	}
	if len(c.Token) < 32 || strings.TrimSpace(c.Token) != c.Token {
		return Config{}, errors.New("KANKAL_BEARER_TOKEN must contain at least 32 bytes")
	}
	return c, nil
}

func main() {
	config, err := LoadConfig()
	if err != nil {
		slog.Error("configuration_invalid")
		os.Exit(1)
	}
	gin.SetMode(gin.ReleaseMode)
	var store ItemStore = NewMemoryStore()
	if config.DatabaseURL != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		postgresStore, err := NewPostgresStore(ctx, config.DatabaseURL)
		cancel()
		if err != nil {
			slog.Error("database_unavailable_or_schema_missing")
			os.Exit(1)
		}
		defer postgresStore.Close()
		store = postgresStore
	}
	server := &http.Server{Addr: config.Address, Handler: NewRouter(config.Token, store), ReadHeaderTimeout: 5 * time.Second}
	serverErrors := make(chan error, 1)
	go func() {
		slog.Info("server_starting")
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrors <- err
		}
	}()
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-stop:
	case <-serverErrors:
		slog.Error("server_failed")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		slog.Error("server_shutdown_failed")
		os.Exit(1)
	}
	slog.Info("server_stopped")
}

func NewRouter(token string, store ItemStore) http.Handler {
	r := gin.New()
	r.Use(outcomeDiagnostics())
	r.Use(safeRecovery())
	r.GET("/live", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "live"}) })
	r.GET("/ready", func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()
		if store.Ping(ctx) != nil {
			writeError(c, http.StatusServiceUnavailable, "service_unavailable", "database unavailable")
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ready"})
	})
	r.GET("/openapi.json", func(c *gin.Context) { c.Data(http.StatusOK, "application/json; charset=utf-8", openAPISpec) })
	r.GET("/docs", func(c *gin.Context) { c.Data(http.StatusOK, "text/html; charset=utf-8", docsHTML) })
	items := r.Group("/api/items", bearerAuth(token))
	items.GET("", func(c *gin.Context) {
		items, err := store.List(c.Request.Context())
		if err != nil {
			writeStoreError(c, err)
			return
		}
		c.JSON(http.StatusOK, items)
	})
	items.POST("", func(c *gin.Context) {
		var input itemInput
		if !decodeBody(c, &input) {
			return
		}
		if !validInput(input) {
			writeError(c, http.StatusBadRequest, "invalid_item", "title is required and must be 1 to 200 characters; description must be at most 2000 characters")
			return
		}
		item, err := store.Create(c.Request.Context(), input)
		if err != nil {
			writeStoreError(c, err)
			return
		}
		c.Header("Location", "/api/items/"+item.ID)
		c.JSON(http.StatusCreated, item)
	})
	items.GET("/:id", func(c *gin.Context) {
		item, ok, err := store.Get(c.Request.Context(), c.Param("id"))
		if err != nil {
			writeStoreError(c, err)
			return
		}
		if !ok {
			writeError(c, 404, "not_found", "item not found")
			return
		}
		c.JSON(200, item)
	})
	items.PUT("/:id", func(c *gin.Context) {
		var input itemInput
		if !decodeBody(c, &input) {
			return
		}
		if !validInput(input) {
			writeError(c, 400, "invalid_item", "title is required and must be 1 to 200 characters; description must be at most 2000 characters")
			return
		}
		item, ok, err := store.Replace(c.Request.Context(), c.Param("id"), input)
		if err != nil {
			writeStoreError(c, err)
			return
		}
		if !ok {
			writeError(c, 404, "not_found", "item not found")
			return
		}
		c.JSON(200, item)
	})
	items.DELETE("/:id", func(c *gin.Context) {
		deleted, err := store.Delete(c.Request.Context(), c.Param("id"))
		if err != nil {
			writeStoreError(c, err)
			return
		}
		if !deleted {
			writeError(c, 404, "not_found", "item not found")
			return
		}
		c.Status(http.StatusNoContent)
	})
	return r
}

func writeStoreError(c *gin.Context, err error) {
	var postgresError *pgconn.PgError
	if errors.As(err, &postgresError) {
		writeError(c, http.StatusInternalServerError, "internal_error", "an unexpected error occurred")
		return
	}
	writeError(c, http.StatusServiceUnavailable, "service_unavailable", "database unavailable")
}
