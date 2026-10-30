package llminference

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPickModel_Exact(t *testing.T) {
	got := PickModel("qwen2", []string{"qwen2", "other"})
	if got.ModelID != "qwen2" || got.AutoDiscovered {
		t.Fatalf("got %+v", got)
	}
}

func TestPickModel_PrefixMatch(t *testing.T) {
	got := PickModel("qwen2", []string{"qwen2.5-0.5b-instruct-q4_k_m.gguf"})
	if got.ModelID != "qwen2.5-0.5b-instruct-q4_k_m.gguf" || !got.AutoDiscovered {
		t.Fatalf("got %+v", got)
	}
}

func TestPickModel_FallbackFirst(t *testing.T) {
	got := PickModel("missing", []string{"llama-3.2"})
	if got.ModelID != "llama-3.2" || !got.AutoDiscovered {
		t.Fatalf("got %+v", got)
	}
}

func TestPickModel_EmptyPreferred(t *testing.T) {
	got := PickModel("", []string{"only-one"})
	if got.ModelID != "only-one" || !got.AutoDiscovered {
		t.Fatalf("got %+v", got)
	}
}

func TestParseAdminParameters(t *testing.T) {
	raw := "temperature 0.8\ntop_p 0.9\ntop_k 40\nrepeat_penalty 1.1\nnum_ctx 4096\nseed 42\nunknown_key 1\n"
	got := ParseAdminParameters(raw)
	if got["temperature"] != 0.8 || got["num_ctx"] != 4096 || got["seed"] != 42 {
		t.Fatalf("unexpected parsed parameters: %+v", got)
	}
	if _, ok := got["unknown_key"]; ok {
		t.Fatalf("unexpected unknown_key in %+v", got)
	}
}

func TestCreateAdminModelAndPullModel(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/create":
			_, _ = io.WriteString(w, `{"status":"success"}`)
		case "/api/pull":
			_, _ = io.WriteString(w, `{"status":"success"}`)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	cfg := Config{BaseURL: server.URL, APIStyle: APIOllama}
	if err := CreateAdminModel(context.Background(), cfg, "custom:latest", "qwen2.5:7b", "sys", "", map[string]float64{"temperature": 0.7}); err != nil {
		t.Fatalf("CreateAdminModel failed: %v", err)
	}
	st, err := PullModel(context.Background(), cfg, "qwen2.5:7b")
	if err != nil || st != "success" {
		t.Fatalf("PullModel got (%q, %v)", st, err)
	}
}
