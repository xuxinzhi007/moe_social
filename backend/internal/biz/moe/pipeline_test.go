package moebiz

import (
	"context"
	"testing"
)

func TestGetBrainPipeline_EmptyAgentKey(t *testing.T) {
	snap, err := GetBrainPipeline(context.Background(), nil, "")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if snap.AgentKey != "" {
		t.Fatalf("agent_key=%q want empty", snap.AgentKey)
	}
	if len(snap.Steps) != 0 {
		t.Fatalf("steps=%d want no fabricated placeholders", len(snap.Steps))
	}
	if snap.HasRun {
		t.Fatal("expected HasRun=false")
	}
}

func TestGetBrainPipeline_NoRunHasNoSteps(t *testing.T) {
	snap, _ := GetBrainPipeline(context.Background(), nil, "demo-bot")
	if len(snap.Steps) != 0 {
		t.Fatalf("steps=%+v", snap.Steps)
	}
}
