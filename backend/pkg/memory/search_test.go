package memory

import (
	"testing"
	"time"
)

func TestSearchFacing_keywordHit(t *testing.T) {
	now := time.Now()
	records := []Record{
		{ID: "1", Key: "user_nickname", Value: "新新", MemoryType: "fact", Source: "heuristic_extract", UpdatedAt: now},
		{ID: "2", Key: "hobby", Value: "咖啡", MemoryType: "preference", Source: "heuristic_extract", UpdatedAt: now.Add(-time.Hour)},
	}
	res := SearchFacing(records, "新新", 8)
	if res.Total != 1 {
		t.Fatalf("expected 1 hit, got %d", res.Total)
	}
	if res.Items[0].Content != "新新" {
		t.Fatalf("unexpected content: %s", res.Items[0].Content)
	}
}

func TestSearchFacing_skipsTechnical(t *testing.T) {
	records := []Record{
		{ID: "1", Key: "device_info:abc", Value: "{}", Source: "device_sync", UpdatedAt: time.Now()},
	}
	res := SearchFacing(records, "abc", 8)
	if res.Total != 0 {
		t.Fatalf("expected 0, got %d", res.Total)
	}
}

func TestBuildProfiles_groupsByType(t *testing.T) {
	records := []Record{
		{Key: "user_nickname", Value: "新新", MemoryType: "fact", Confidence: 0.8},
		{Key: "like", Value: "咖啡", MemoryType: "preference", Confidence: 0.7},
	}
	profiles := BuildProfiles(records)
	if len(profiles) != 2 {
		t.Fatalf("expected 2 profile groups, got %d", len(profiles))
	}
}
