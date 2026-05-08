package llm

import (
	"testing"
	"time"

	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func TestUserMemoryCache_HitAndExpire(t *testing.T) {
	userID := "u-cache-test"
	invalidateCachedUserMemories(userID)

	items := []*super.UserMemory{
		{Key: "hobby", Value: "画画"},
	}
	setCachedUserMemories(userID, items)

	got, ok := getCachedUserMemories(userID)
	if !ok {
		t.Fatalf("expected cache hit")
	}
	if len(got) != 1 || got[0].Value != "画画" {
		t.Fatalf("unexpected cached value: %+v", got)
	}

	// Force expire and verify miss.
	userMemoryCache.Lock()
	entry := userMemoryCache.data[userID]
	entry.expiresAt = time.Now().Add(-time.Second)
	userMemoryCache.data[userID] = entry
	userMemoryCache.Unlock()

	if _, ok := getCachedUserMemories(userID); ok {
		t.Fatalf("expected cache miss after expiration")
	}
}

func TestSelectRelevantMemoryLines_FallbackToRecentWhenNoKeywordHit(t *testing.T) {
	memories := []*super.UserMemory{
		{Key: "hobby", Value: "画画"},
		{Key: "food", Value: "拉面"},
		{Key: "music", Value: "轻音乐"},
	}
	messages := []types.LlmMessage{
		{Role: "user", Content: "今天心情一般"},
	}

	lines := selectRelevantMemoryLines(memories, messages)
	if len(lines) == 0 {
		t.Fatalf("expected fallback memory lines, got empty result")
	}
	if len(lines) > fallbackMemoryItems {
		t.Fatalf("expected at most %d fallback lines, got %d", fallbackMemoryItems, len(lines))
	}
}

func TestSelectRelevantMemoryLines_KeywordHitPrefersRelevantMemories(t *testing.T) {
	memories := []*super.UserMemory{
		{Key: "hobby", Value: "画画"},
		{Key: "pet", Value: "猫"},
		{Key: "food", Value: "拉面"},
		{Key: "noise", Value: "unknown"},
		{Key: "hobby", Value: "画画"},
	}
	messages := []types.LlmMessage{
		{Role: "user", Content: "给我推荐一些画画主题"},
	}

	lines := selectRelevantMemoryLines(memories, messages)
	if len(lines) == 0 {
		t.Fatalf("expected non-empty selected lines")
	}
	if len(lines) > maxInjectedMemoryItems {
		t.Fatalf("expected at most %d selected lines, got %d", maxInjectedMemoryItems, len(lines))
	}

	found := false
	for _, line := range lines {
		if line == "hobby: 画画" {
			found = true
		}
		if line == "noise: unknown" {
			t.Fatalf("noise memory should be filtered out")
		}
	}
	if !found {
		t.Fatalf("expected relevant memory line to be selected")
	}
}
