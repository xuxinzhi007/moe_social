package memory

import (
	"strings"
	"testing"
	"time"
)

func TestRecentDailyNotes(t *testing.T) {
	now := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	records := []Record{
		{Key: DailyNoteKey(now), Value: "today line"},
		{Key: DailyNoteKey(now.Add(-24 * time.Hour)), Value: "yesterday"},
		{Key: DailyNoteKey(now.Add(-48 * time.Hour)), Value: "old"},
	}
	got := RecentDailyNotes(records, now)
	if len(got) != 2 {
		t.Fatalf("expected 2 daily notes, got %d", len(got))
	}
}

func TestComposeBootstrap_layers(t *testing.T) {
	block := ComposeBootstrap(BootstrapInput{
		Profiles: []ProfileSummary{
			{MemoryType: "fact", Summary: "昵称新新", ItemCount: 1, Confidence: 0.8},
		},
		DailyNotes: []Record{
			{Key: "daily_note:2026-05-20", Value: "回合 用户:你好"},
		},
		SearchItems: []DisplayItem{
			{Title: "昵称", Content: "新新", Category: "了解"},
		},
		Budget: DefaultBootstrapBudget(),
	})
	if block == "" {
		t.Fatal("expected non-empty bootstrap block")
	}
	for _, part := range []string{"精选层", "日记", "检索"} {
		if !strings.Contains(block, part) {
			t.Fatalf("missing %q in block: %s", part, block)
		}
	}
}
