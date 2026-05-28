package runtime

import (
	"testing"
	"time"
)

func TestLiveRunsTryBeginAndEnd(t *testing.T) {
	key := "test_agent_live_run"
	LiveRuns.End(key)

	sess, ok := LiveRuns.TryBegin(key)
	if !ok || sess == nil {
		t.Fatal("expected TryBegin ok")
	}
	if LiveRuns.IsRunning(key) != true {
		t.Fatal("expected running")
	}
	_, ok2 := LiveRuns.TryBegin(key)
	if ok2 {
		t.Fatal("expected duplicate TryBegin to fail")
	}
	LiveRuns.End(key)
	if LiveRuns.IsRunning(key) {
		t.Fatal("expected not running after End")
	}
}

func TestLiveRunPipelineSteps(t *testing.T) {
	key := "test_agent_steps"
	LiveRuns.End(key)
	sess, ok := LiveRuns.TryBegin(key)
	if !ok {
		t.Fatal("TryBegin")
	}
	defer LiveRuns.End(key)

	sess.SetActive("load_runtime", "加载 Bot 配置")
	steps := LiveRuns.PipelineStepsForAgent(key)
	if len(steps) != 1 || steps[0].Status != "running" {
		t.Fatalf("expected one running step, got %+v", steps)
	}

	sess.SyncSteps([]RunStep{{Key: "load_runtime", Label: "加载 Bot 配置", Status: "ok", MS: 10}})
	sess.SetActive("gather_memory", "检索记忆")
	steps = LiveRuns.PipelineStepsForAgent(key)
	if len(steps) != 2 {
		t.Fatalf("expected 2 steps, got %d", len(steps))
	}
	if steps[1].Status != "running" {
		t.Fatalf("expected second running, got %+v", steps[1])
	}

	snap, ok := LiveRuns.SnapshotForAgent(key)
	if !ok || snap.CurrentPhase != string(PhaseMemory) {
		t.Fatalf("phase want memory, got %q", snap.CurrentPhase)
	}
	if snap.StartedAt.IsZero() || time.Since(snap.StartedAt) > time.Minute {
		t.Fatalf("unexpected startedAt %v", snap.StartedAt)
	}
}
