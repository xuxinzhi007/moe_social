package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCorsFilterOptionsPreflight(t *testing.T) {
	t.Parallel()

	chain := corsFilter(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))

	req := httptest.NewRequest(http.MethodOptions, "/api/user/login", nil)
	req.Header.Set("Origin", "http://localhost:59829")
	req.Header.Set("Access-Control-Request-Method", "POST")
	rec := httptest.NewRecorder()

	chain.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNoContent)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:59829" {
		t.Fatalf("Access-Control-Allow-Origin = %q, want origin echo", got)
	}
}

func TestCorsFilterAddsHeadersOnGet(t *testing.T) {
	t.Parallel()

	chain := corsFilter(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()

	chain.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5173" {
		t.Fatalf("Access-Control-Allow-Origin = %q, want echoed origin", got)
	}
}
