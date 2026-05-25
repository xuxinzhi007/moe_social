package utils

import (
	"testing"
	"time"

	"backend/model"
)

func TestBuildBehaviorTagsSocialActive(t *testing.T) {
	rows := []model.UserBehaviorDaily{
		{Screen: "chat", VisitCount: 2, ActivityDate: time.Now().UTC()},
		{Screen: "conversations", VisitCount: 2, ActivityDate: time.Now().UTC()},
	}
	tags := BuildBehaviorTags(rows)
	if len(tags) == 0 {
		t.Fatal("expected tags")
	}
	found := false
	for _, tag := range tags {
		if tag == "社交活跃" {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected 社交活跃 in %v", tags)
	}
}

func TestNormalizeBehaviorScreen(t *testing.T) {
	if got := NormalizeBehaviorScreen("  VIP_CENTER  "); got != "vip_center" {
		t.Fatalf("got %q", got)
	}
}
