package common

import (
	"net/http"
	"testing"
)

func TestClientIPFromRequest(t *testing.T) {
	r, err := http.NewRequest(http.MethodPost, "/api/landing/feedback", nil)
	if err != nil {
		t.Fatal(err)
	}
	r.Header.Set("X-Forwarded-For", "203.0.113.1, 10.0.0.1")
	if got := ClientIPFromRequest(r); got != "203.0.113.1" {
		t.Fatalf("xff: got %q want 203.0.113.1", got)
	}

	r.Header.Del("X-Forwarded-For")
	r.Header.Set("X-Real-IP", "198.51.100.2")
	if got := ClientIPFromRequest(r); got != "198.51.100.2" {
		t.Fatalf("xri: got %q want 198.51.100.2", got)
	}

	r.Header.Del("X-Real-IP")
	r.RemoteAddr = "192.0.2.3:12345"
	if got := ClientIPFromRequest(r); got != "192.0.2.3" {
		t.Fatalf("remote: got %q want 192.0.2.3", got)
	}
}
