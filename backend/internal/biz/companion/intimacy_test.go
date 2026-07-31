package companionbiz

import (
	"context"
	"testing"

	"backend/pkg/llminference"
)

func TestApplyIntimacyDelta(t *testing.T) {
	score, level := ApplyIntimacyDelta(0, IntimacyDeltaChat)
	if score != 2 || level != 1 {
		t.Fatalf("got score=%v level=%d, want 2 / 1", score, level)
	}
	score, level = ApplyIntimacyDelta(9, IntimacyDeltaChat)
	if score != 11 || level != 2 {
		t.Fatalf("got score=%v level=%d, want 11 / 2", score, level)
	}
	score, level = ApplyIntimacyDelta(99, IntimacyDeltaChat)
	if score != 100 || level != 10 {
		t.Fatalf("got score=%v level=%d, want 100 / 10", score, level)
	}
}

func TestBumpIntimacyPersists(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{Name: "小花", IntimacyScore: 0, RelationshipLevel: 1})
	engine := NewEngine(store, nil, llminference.Config{}, "")

	if err := engine.BumpIntimacy(context.Background(), 7, IntimacyDeltaCare); err != nil {
		t.Fatalf("BumpIntimacy() error = %v", err)
	}
	row := store.profiles[7]
	if row.IntimacyScore != 1 || row.RelationshipLevel != 1 {
		t.Fatalf("intimacy=%v level=%d, want 1 / 1", row.IntimacyScore, row.RelationshipLevel)
	}
}
