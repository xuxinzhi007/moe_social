package transport

import (
	"testing"

	moeadmin "backend/internal/service/moe"
	"backend/model"
)

func TestCanTriggerRuntime(t *testing.T) {
	rt := &model.MoeAgentRuntime{BotUserID: 42}
	if !canTriggerRuntime(rt, 42) {
		t.Fatal("expected bot owner to be allowed")
	}
	if canTriggerRuntime(rt, 7) {
		t.Fatal("expected other users to be denied")
	}
	if canTriggerRuntime(nil, 42) {
		t.Fatal("expected nil runtime to be denied")
	}
}

func TestTriggerDetail(t *testing.T) {
	if got := triggerDetail(moeadmin.RunOnceInvokeResult{Accepted: true}); got == "" {
		t.Fatal("expected accepted detail")
	}
	if got := triggerDetail(moeadmin.RunOnceInvokeResult{AlreadyRunning: true}); got == "" {
		t.Fatal("expected already running detail")
	}
}
