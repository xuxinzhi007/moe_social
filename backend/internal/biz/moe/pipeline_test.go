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
	if len(snap.Steps) != 5 {
		t.Fatalf("steps=%d want 5 default placeholders", len(snap.Steps))
	}
	if snap.HasRun {
		t.Fatal("expected HasRun=false")
	}
}

func TestGetBrainPipeline_DefaultStepsLabels(t *testing.T) {
	snap, _ := GetBrainPipeline(context.Background(), nil, "demo-bot")
	if snap.Steps[0].Key != "load_runtime" {
		t.Fatalf("first step key=%q", snap.Steps[0].Key)
	}
}
