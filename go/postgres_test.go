package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestPostgresItemSurvivesRouterRestart(t *testing.T) {
	url := os.Getenv("KANKAL_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set KANKAL_TEST_DATABASE_URL to an isolated, migrated local test database")
	}
	ctx := context.Background()
	first, err := NewPostgresStore(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	token := "starter-secret-that-is-at-least-32-chars"
	create := httptest.NewRequest(http.MethodPost, "/api/items", strings.NewReader(`{"title":"Survives restart"}`))
	create.Header.Set("Authorization", "Bearer "+token)
	created := httptest.NewRecorder()
	NewRouter(token, first).ServeHTTP(created, create)
	if created.Code != http.StatusCreated {
		t.Fatalf("create: got %d, want 201", created.Code)
	}
	var item Item
	if err := json.Unmarshal(created.Body.Bytes(), &item); err != nil {
		t.Fatal(err)
	}
	first.Close()

	second, err := NewPostgresStore(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Close()
	router := NewRouter(token, second)
	read := httptest.NewRequest(http.MethodGet, "/api/items/"+item.ID, nil)
	read.Header.Set("Authorization", "Bearer "+token)
	got := httptest.NewRecorder()
	router.ServeHTTP(got, read)
	if got.Code != http.StatusOK {
		t.Fatalf("read after restart: got %d, want 200", got.Code)
	}
	var persisted Item
	if err := json.Unmarshal(got.Body.Bytes(), &persisted); err != nil {
		t.Fatal(err)
	}
	if persisted != item {
		t.Fatalf("read after restart: got %+v, want %+v", persisted, item)
	}
	request := func(method, path, body string) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		response := httptest.NewRecorder()
		router.ServeHTTP(response, req)
		return response
	}
	updated := request(http.MethodPut, "/api/items/"+item.ID, `{"title":"Updated","description":"stored"}`)
	if updated.Code != http.StatusOK {
		t.Fatalf("update: got %d, want 200", updated.Code)
	}
	listed := request(http.MethodGet, "/api/items", "")
	if listed.Code != http.StatusOK {
		t.Fatalf("list: got %d, want 200", listed.Code)
	}
	var items []Item
	if err := json.Unmarshal(listed.Body.Bytes(), &items); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, candidate := range items {
		if candidate.ID == item.ID && candidate.Title == "Updated" && candidate.Description == "stored" {
			found = true
		}
	}
	if !found {
		t.Fatal("updated item missing from database-backed list")
	}
	deleted := request(http.MethodDelete, "/api/items/"+item.ID, "")
	if deleted.Code != http.StatusNoContent {
		t.Fatalf("delete: got %d, want 204", deleted.Code)
	}
	missing := request(http.MethodGet, "/api/items/"+item.ID, "")
	if missing.Code != http.StatusNotFound {
		t.Fatalf("get after delete: got %d, want 404", missing.Code)
	}
	second.Close()
	ready := httptest.NewRecorder()
	router.ServeHTTP(ready, httptest.NewRequest(http.MethodGet, "/ready", nil))
	if ready.Code != http.StatusServiceUnavailable || !strings.Contains(ready.Body.String(), `"service_unavailable"`) {
		t.Fatalf("readiness after database closes: got %d and %q", ready.Code, ready.Body.String())
	}
}
