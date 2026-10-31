package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestItemRoutesRequireConfiguredBearerToken(t *testing.T) {
	router := NewRouter("starter-secret-that-is-at-least-32-chars", NewMemoryStore())
	for _, header := range []string{"", "Bearer wrong-secret-that-is-at-least-32-chars", "Basic starter-secret-that-is-at-least-32-chars"} {
		request := httptest.NewRequest("GET", "/api/items", nil)
		request.Header.Set("Authorization", header)
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if response.Code != 401 {
			t.Fatalf("GET /api/items with invalid authorization: got %d, want 401", response.Code)
		}
	}
}

func TestAuthenticatedItemJourneyAndValidation(t *testing.T) {
	server := httptest.NewServer(NewRouter("starter-secret-that-is-at-least-32-chars", NewMemoryStore()))
	defer server.Close()
	client := server.Client()
	client.Timeout = 5 * time.Second
	do := func(method, path, body string, auth bool) *http.Response {
		t.Helper()
		request, err := http.NewRequest(method, server.URL+path, strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		if body != "" {
			request.Header.Set("Content-Type", "application/json")
		}
		if auth {
			request.Header.Set("Authorization", "Bearer starter-secret-that-is-at-least-32-chars")
		}
		response, err := client.Do(request)
		if err != nil {
			t.Fatal(err)
		}
		return response
	}
	for _, path := range []string{"/live", "/ready"} {
		response := do("GET", path, "", false)
		if response.StatusCode != 200 {
			t.Fatalf("GET %s: got %d, want 200", path, response.StatusCode)
		}
		response.Body.Close()
	}
	unauthorized := do("GET", "/api/items", "", false)
	if unauthorized.StatusCode != 401 {
		t.Fatalf("unauthenticated list: got %d, want 401", unauthorized.StatusCode)
	}
	unauthorized.Body.Close()
	w := do("POST", "/api/items", `{"title":"  "}`, true)
	if w.StatusCode != 400 {
		t.Fatalf("blank title: got %d, want 400", w.StatusCode)
	}
	w.Body.Close()
	created := do("POST", "/api/items", `{"title":"First","description":"note"}`, true)
	if created.StatusCode != 201 {
		t.Fatalf("create: got %d, want 201", created.StatusCode)
	}
	var item Item
	if err := json.NewDecoder(created.Body).Decode(&item); err != nil {
		t.Fatal(err)
	}
	created.Body.Close()
	if item.ID == "" || item.Title != "First" || item.Description != "note" {
		t.Fatalf("unexpected create response: %+v", item)
	}
	got := do("GET", "/api/items/"+item.ID, "", true)
	if got.StatusCode != 200 {
		t.Fatalf("get: got %d, want 200", got.StatusCode)
	}
	got.Body.Close()
	updated := do("PUT", "/api/items/"+item.ID, `{"title":"Updated","description":"changed"}`, true)
	if updated.StatusCode != 200 {
		t.Fatalf("update: got %d, want 200", updated.StatusCode)
	}
	updated.Body.Close()
	list := do("GET", "/api/items", "", true)
	if list.StatusCode != 200 {
		t.Fatalf("list: got %d, want 200", list.StatusCode)
	}
	var items []Item
	if err := json.NewDecoder(list.Body).Decode(&items); err != nil {
		t.Fatal(err)
	}
	list.Body.Close()
	if len(items) != 1 || items[0].Title != "Updated" {
		t.Fatalf("unexpected list: %+v", items)
	}
	deleted := do("DELETE", "/api/items/"+item.ID, "", true)
	if deleted.StatusCode != 204 {
		t.Fatalf("delete: got %d, want 204", deleted.StatusCode)
	}
	deleted.Body.Close()
	missing := do("GET", "/api/items/"+item.ID, "", true)
	if missing.StatusCode != 404 {
		t.Fatalf("deleted item lookup: got %d, want 404", missing.StatusCode)
	}
	var failure map[string]any
	if err := json.NewDecoder(missing.Body).Decode(&failure); err != nil {
		t.Fatal(err)
	}
	missing.Body.Close()
	if !bytes.Contains([]byte(failure["error"].(map[string]any)["message"].(string)), []byte("item not found")) {
		t.Fatalf("unexpected safe error: %v", failure)
	}
}

func TestMalformedAndOversizedBodiesHaveFixedErrors(t *testing.T) {
	router := NewRouter("secret-that-is-at-least-32-characters", NewMemoryStore())
	for _, test := range []struct {
		name, body string
		want       int
	}{
		{"malformed", `{`, 400},
		{"unknown_field", `{"title":"ok","private":"value"}`, 400},
		{"multiple_values", `{"title":"ok"}{}`, 400},
		{"oversized", `{"title":"` + strings.Repeat("x", maxBodyBytes) + `"}`, 413},
	} {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest("POST", "/api/items", strings.NewReader(test.body))
			request.Header.Set("Authorization", "Bearer secret-that-is-at-least-32-characters")
			response := httptest.NewRecorder()
			router.ServeHTTP(response, request)
			if response.Code != test.want {
				t.Fatalf("got %d, want %d: %s", response.Code, test.want, response.Body.String())
			}
			if strings.Contains(response.Body.String(), "private") || strings.Contains(response.Body.String(), "value") {
				t.Fatal("error exposed request data")
			}
		})
	}
}

func TestLoadConfigRejectsMissingOrWeakBearerToken(t *testing.T) {
	for _, token := range []string{"", "short", "  " + strings.Repeat("x", 32)} {
		t.Setenv("KANKAL_BEARER_TOKEN", token)
		if _, err := LoadConfig(); err == nil {
			t.Fatal("expected invalid bearer token to be rejected")
		}
	}
	t.Setenv("KANKAL_BEARER_TOKEN", strings.Repeat("x", 32))
	t.Setenv("KANKAL_ADDR", "")
	defaultConfig, err := LoadConfig()
	if err != nil {
		t.Fatal("valid token rejected")
	}
	if defaultConfig.Address != "127.0.0.1:8080" {
		t.Fatalf("default address = %q, want loopback-only address", defaultConfig.Address)
	}
	t.Setenv("KANKAL_ADDR", " 127.0.0.1:9999 ")
	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal("valid token rejected")
	}
	if cfg.Address != "127.0.0.1:9999" {
		t.Fatalf("address = %q", cfg.Address)
	}
	if cfg.Token != strings.Repeat("x", 32) {
		t.Fatal("token changed during configuration load")
	}
}

func TestPublicAPIDocumentation(t *testing.T) {
	router := NewRouter("starter-secret-that-is-at-least-32-chars", NewMemoryStore())
	specRequest := httptest.NewRequest(http.MethodGet, "/openapi.json", nil)
	specResponse := httptest.NewRecorder()
	router.ServeHTTP(specResponse, specRequest)
	if specResponse.Code != http.StatusOK {
		t.Fatalf("GET /openapi.json: got %d, want 200", specResponse.Code)
	}
	var spec struct {
		OpenAPI string                     `json:"openapi"`
		Paths   map[string]json.RawMessage `json:"paths"`
	}
	if err := json.Unmarshal(specResponse.Body.Bytes(), &spec); err != nil {
		t.Fatalf("invalid OpenAPI JSON: %v", err)
	}
	if !strings.HasPrefix(spec.OpenAPI, "3.1.") || len(spec.Paths) == 0 {
		t.Fatalf("unexpected OpenAPI document version %q or empty paths", spec.OpenAPI)
	}

	docsRequest := httptest.NewRequest(http.MethodGet, "/docs", nil)
	docsResponse := httptest.NewRecorder()
	router.ServeHTTP(docsResponse, docsRequest)
	if docsResponse.Code != http.StatusOK || !strings.Contains(docsResponse.Header().Get("Content-Type"), "text/html") {
		t.Fatalf("GET /docs: got %d and %q, want HTML 200", docsResponse.Code, docsResponse.Header().Get("Content-Type"))
	}
	if !strings.Contains(docsResponse.Body.String(), "/openapi.json") {
		t.Fatal("documentation page does not load the published OpenAPI document")
	}
}
