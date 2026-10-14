package companionbiz

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	lifebiz "backend/internal/biz/life"
	"backend/model"
	"backend/pkg/llminference"
)

func heroSummaryLifeStore(now time.Time) *fakeLifeStore {
	return &fakeLifeStore{
		entities: []model.LifeEntity{{
			ID:       9,
			Name:     "小星",
			HeroSlug: lifebiz.HeroSlugXiaoxing,
			IsAlive:  true,
		}},
		events: []model.LifeEventLog{
			{EntityID: 9, EventType: "interaction", Description: "小星帮新居民找到了营地", CreatedAt: now.Add(-5 * time.Hour)},
			{EntityID: 9, EventType: "walk", Description: "小星沿着河边散步", CreatedAt: now.Add(-4 * time.Hour)},
			{EntityID: 9, EventType: "eat", Description: "小星吃了一顿热乎的炖菜", CreatedAt: now.Add(-3 * time.Hour)},
			{EntityID: 9, EventType: "idle", Description: "小星发了一会儿呆", CreatedAt: now.Add(-3 * time.Hour)},
			{EntityID: 9, EventType: "walk", Description: "小星巡视了旧营地", CreatedAt: now.Add(-30 * time.Hour)},
		},
	}
}

func countMemoriesByType(store *fakeStore, memoryType string) int {
	count := 0
	for _, memory := range store.memories {
		if memory.MemoryType == memoryType {
			count++
		}
	}
	return count
}

func TestHeroOfflineSummaryGeneratesAndMovesWatermark(t *testing.T) {
	now := time.Date(2026, 10, 14, 12, 0, 0, 0, time.UTC)
	store := newFakeStore()
	engine := NewEngine(store, heroSummaryLifeStore(now), llminference.Config{}, "")

	summary, err := engine.HeroOfflineSummary(context.Background(), 7, lifebiz.HeroSlugXiaoxing, now)
	if err != nil {
		t.Fatalf("HeroOfflineSummary() error = %v", err)
	}
	if summary == nil {
		t.Fatal("HeroOfflineSummary() = nil, want summary for 24h window with events")
	}
	if summary.EventCount != 3 {
		t.Fatalf("EventCount = %d, want 3 (idle filtered, old event out of window)", summary.EventCount)
	}
	for _, want := range []string{"你不在的 24 小时里", "小星帮新居民找到了营地", "小星吃了一顿热乎的炖菜"} {
		if !strings.Contains(summary.Text, want) {
			t.Fatalf("summary text missing %q: %s", want, summary.Text)
		}
	}
	if strings.Contains(summary.Text, "旧营地") {
		t.Fatalf("summary text leaked out-of-window event: %s", summary.Text)
	}
	if strings.Contains(summary.Text, "发呆") {
		t.Fatalf("summary text leaked idle event: %s", summary.Text)
	}

	if countMemoriesByType(store, "fact") != 1 {
		t.Fatalf("fact memories = %+v, want exactly one summary memory", store.memories)
	}
	if countMemoriesByType(store, heroSystemMemoryType) != 1 {
		t.Fatalf("system memories = %+v, want exactly one watermark", store.memories)
	}

	// 同一时刻重复调用：窗口不足 2h，不再生成。
	again, err := engine.HeroOfflineSummary(context.Background(), 7, lifebiz.HeroSlugXiaoxing, now)
	if err != nil {
		t.Fatalf("HeroOfflineSummary() second call error = %v", err)
	}
	if again != nil {
		t.Fatalf("second call = %+v, want nil (watermark just moved)", again)
	}

	// 3 小时后带新事件：再次生成，水位线更新而非重复。
	later := now.Add(3 * time.Hour)
	engine.lifeStore.(*fakeLifeStore).events = append(
		engine.lifeStore.(*fakeLifeStore).events,
		model.LifeEventLog{
			EntityID:    9,
			EventType:   "interaction",
			Description: "小星和营地居民一起看了流星",
			CreatedAt:   later.Add(-time.Hour),
		},
	)
	third, err := engine.HeroOfflineSummary(context.Background(), 7, lifebiz.HeroSlugXiaoxing, later)
	if err != nil {
		t.Fatalf("HeroOfflineSummary() third call error = %v", err)
	}
	if third == nil || !strings.Contains(third.Text, "看了流星") {
		t.Fatalf("third call = %+v, want summary narrating the new event", third)
	}
	if countMemoriesByType(store, heroSystemMemoryType) != 1 {
		t.Fatalf("system memories = %+v, want watermark updated in place", store.memories)
	}
}

func TestHeroOfflineSummaryUnknownSlug(t *testing.T) {
	engine := NewEngine(newFakeStore(), nil, llminference.Config{}, "")
	_, err := engine.HeroOfflineSummary(context.Background(), 7, "ghost", time.Now())
	if !errors.Is(err, ErrHeroNotFound) {
		t.Fatalf("HeroOfflineSummary() error = %v, want ErrHeroNotFound", err)
	}
}

func TestHeroOfflineSummaryQuietWindowOnlyMovesWatermark(t *testing.T) {
	now := time.Date(2026, 10, 14, 12, 0, 0, 0, time.UTC)
	store := newFakeStore()
	lifeStore := &fakeLifeStore{
		entities: []model.LifeEntity{{
			ID:       9,
			Name:     "小星",
			HeroSlug: lifebiz.HeroSlugXiaoxing,
			IsAlive:  true,
		}},
	}
	engine := NewEngine(store, lifeStore, llminference.Config{}, "")

	summary, err := engine.HeroOfflineSummary(context.Background(), 7, lifebiz.HeroSlugXiaoxing, now)
	if err != nil {
		t.Fatalf("HeroOfflineSummary() error = %v", err)
	}
	if summary != nil {
		t.Fatalf("summary = %+v, want nil for quiet window", summary)
	}
	if countMemoriesByType(store, heroSystemMemoryType) != 1 {
		t.Fatalf("system memories = %+v, want watermark moved even without events", store.memories)
	}
	if countMemoriesByType(store, "fact") != 0 {
		t.Fatalf("fact memories = %+v, want none for quiet window", store.memories)
	}
}

func TestHeroChatPromptExcludesSystemMemories(t *testing.T) {
	hero, _ := lifebiz.HeroForSlug(lifebiz.HeroSlugXiaoxing)
	prompt := buildHeroSystemPrompt(hero, nil, nil, []model.CompanionMemory{
		{MemoryType: "fact", Content: "TA送过三次花"},
		{MemoryType: heroSystemMemoryType, MemoryKey: heroSummaryWatermarkKey, Content: "2026-10-14T08:00:00Z"},
	})
	if !strings.Contains(prompt, "TA送过三次花") {
		t.Fatalf("prompt missing user-facing memory: %s", prompt)
	}
	if strings.Contains(prompt, "2026-10-14T08:00:00Z") {
		t.Fatalf("prompt leaked system watermark row: %s", prompt)
	}
}
