package postpulse

import "testing"

func TestTokenize(t *testing.T) {
	toks := tokenize("治愈 手绘")
	if len(toks) < 2 {
		t.Fatalf("expected tokens, got %v", toks)
	}
}

func TestSnippet(t *testing.T) {
	s := snippet("你好世界", 2)
	if s == "" {
		t.Fatal("snippet empty")
	}
}
