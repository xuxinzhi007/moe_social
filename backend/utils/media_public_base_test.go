package utils

import (
	"net/http/httptest"
	"testing"
)

func TestResolveMediaPublicBase(t *testing.T) {
	req := httptest.NewRequest("GET", "http://127.0.0.1:8888/api/admin/media/images", nil)
	req.Host = "127.0.0.1:8888"
	got := ResolveMediaPublicBase(req, "", "http://47.106.175.49:8888")
	if got != "http://127.0.0.1:8888" {
		t.Fatalf("request host: got %q", got)
	}
	got = ResolveMediaPublicBase(nil, "https://cdn.example.com", "http://47.106.175.49:8888")
	if got != "https://cdn.example.com" {
		t.Fatalf("explicit image base: got %q", got)
	}
	got = ResolveMediaPublicBase(nil, "", "http://47.106.175.49:8888")
	if got != "http://47.106.175.49:8888" {
		t.Fatalf("client fallback: got %q", got)
	}
}
