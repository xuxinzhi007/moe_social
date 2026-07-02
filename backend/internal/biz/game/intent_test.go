package gamebiz

import "testing"

func TestRuleBasedIntentTravel(t *testing.T) {
	intent := ruleBasedIntent("我想往东走，看看森林")
	if intent.Type != "travel" {
		t.Fatalf("expected travel, got %s", intent.Type)
	}
	if intent.Direction != "东" {
		t.Fatalf("expected 东, got %s", intent.Direction)
	}
}

func TestRuleBasedIntentObserve(t *testing.T) {
	intent := ruleBasedIntent("看看周围有什么")
	if intent.Type != "observe" {
		t.Fatalf("expected observe, got %s", intent.Type)
	}
}
