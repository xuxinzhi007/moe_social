package llminference

import "testing"

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
