package gamebiz

import "testing"

func TestResolveGameLlmModeSmallModel(t *testing.T) {
	if got := ResolveGameLlmMode("", "qwen2.5-0.5b-instruct-q4"); got != GameLlmModeNarrator {
		t.Fatalf("expected narrator for 0.5B, got %s", got)
	}
}

func TestResolveGameLlmModeExplicitAgent(t *testing.T) {
	if got := ResolveGameLlmMode("agent", "qwen2.5-0.5b"); got != GameLlmModeAgent {
		t.Fatalf("expected agent when configured, got %s", got)
	}
}
