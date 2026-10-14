package companiondata

import (
	"context"
	"testing"

	"backend/model"
)

// 锁死活世界 K1 边界：英雄记忆查询永不过用户边界，账号级查询永远读不到英雄记忆。
func TestHeroMemoryNamespaceIsolation(t *testing.T) {
	db := newCompanionTestDB(t)
	if err := db.AutoMigrate(&model.CompanionMemory{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}
	st := &store{db: db}
	ctx := context.Background()

	seed := []model.CompanionMemory{
		{UserID: 7, HeroID: "", MemoryType: "fact", MemoryKey: "favorite_fruit", Content: "喜欢青提"},
		{UserID: 7, HeroID: "lanxing", MemoryType: "fact", MemoryKey: "gift_flower", Content: "送过三次花"},
		{UserID: 8, HeroID: "lanxing", MemoryType: "fact", MemoryKey: "gift_flower", Content: "送过一次花"},
	}
	for i := range seed {
		if err := st.CreateMemory(ctx, &seed[i]); err != nil {
			t.Fatalf("CreateMemory() error = %v", err)
		}
	}

	account, err := st.ListActiveMemories(ctx, 7, 10)
	if err != nil {
		t.Fatalf("ListActiveMemories() error = %v", err)
	}
	if len(account) != 1 || account[0].HeroID != "" {
		t.Fatalf("ListActiveMemories() = %+v, want only the account-scope row", account)
	}

	hero, err := st.ListActiveHeroMemories(ctx, 7, "lanxing", 10)
	if err != nil {
		t.Fatalf("ListActiveHeroMemories() error = %v", err)
	}
	if len(hero) != 1 || hero[0].Content != "送过三次花" {
		t.Fatalf("ListActiveHeroMemories(7, lanxing) = %+v, want only user 7's hero row", hero)
	}

	crossUser, err := st.ListActiveHeroMemories(ctx, 7, "tutu", 10)
	if err != nil {
		t.Fatalf("ListActiveHeroMemories(7, tutu) error = %v", err)
	}
	if len(crossUser) != 0 {
		t.Fatalf("ListActiveHeroMemories(7, tutu) = %+v, want empty", crossUser)
	}

	otherUser, err := st.ListActiveHeroMemories(ctx, 8, "lanxing", 10)
	if err != nil {
		t.Fatalf("ListActiveHeroMemories(8, lanxing) error = %v", err)
	}
	if len(otherUser) != 1 || otherUser[0].Content != "送过一次花" {
		t.Fatalf("ListActiveHeroMemories(8, lanxing) = %+v, want only user 8's hero row", otherUser)
	}
}
