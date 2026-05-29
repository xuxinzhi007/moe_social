package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCorsFilter_preflight(t *testing.T) {
	t.Parallel()
	h := corsFilter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	}))
	req := httptest.NewRequest(http.MethodOptions, "/api/user/3", nil)
	req.Header.Set("Origin", "http://localhost:12345")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNoContent)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:12345" {
		t.Fatalf("Allow-Origin = %q", got)
	}
}

func TestCorsFilter_get(t *testing.T) {
	t.Parallel()
	h := corsFilter(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	req := httptest.NewRequest(http.MethodGet, "/api/user/3", nil)
	req.Header.Set("Origin", "http://localhost:12345")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:12345" {
		t.Fatalf("Allow-Origin = %q", got)
	}
}
