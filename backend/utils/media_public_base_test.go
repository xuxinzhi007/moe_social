package utils

import (
	"net/http/httptest"
	"testing"
)

func TestResolveMediaPublicBase(t *testing.T) {
	req := httptest.NewRequest("GET", "http://request.example.test/api/admin/media/images", nil)
	for _, tt := range []struct {
		name, image, client, want string
		request                   bool
	}{
		{"effective image before host", "https://api.example.test///", "https://client.example.test", "https://api.example.test", true},
		{"client before host", "", "https://client.example.test/", "https://client.example.test", true},
		{"request fallback", "", "", "http://request.example.test", true},
		{"slash overrides are empty", "/", "///", "http://request.example.test", true},
		{"explicit image", "https://images.example.test/", "https://client.example.test", "https://images.example.test", false},
		{"client fallback", "", "https://client.example.test/", "https://client.example.test", false},
		{"local fallback", "///", "/", "http://localhost:8888", false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			r := req
			if !tt.request {
				r = nil
			}
			if got := ResolveMediaPublicBase(r, tt.image, tt.client); got != tt.want {
				t.Fatalf("got %q, want %q", got, tt.want)
			}
		})
	}
}
