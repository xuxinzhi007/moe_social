package companiondata

import (
	"context"
	"testing"

	"backend/model"
)

// 锁死活世界 D1 边界：主伙伴聊天历史永远读不到英雄闲聊，英雄闲聊按 (user, hero) 隔离。
func TestHeroChatLogNamespaceIsolation(t *testing.T) {
	db := newCompanionTestDB(t)
	if err := db.AutoMigrate(&model.CompanionChatLog{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}
	st := &store{db: db}
	ctx := context.Background()

	seed := []model.CompanionChatLog{
		{UserID: 7, HeroID: "", Role: "user", Content: "主伙伴消息"},
		{UserID: 7, HeroID: "xiaoxing", Role: "user", Content: "小星你好"},
		{UserID: 7, HeroID: "xiaoxing", Role: "assistant", Content: "你好呀"},
		{UserID: 8, HeroID: "xiaoxing", Role: "user", Content: "别人的小星"},
	}
	for i := range seed {
		if err := st.AppendChatLog(ctx, &seed[i]); err != nil {
			t.Fatalf("AppendChatLog() error = %v", err)
		}
	}

	account, err := st.ListRecentChatLogs(ctx, 7, 10)
	if err != nil {
		t.Fatalf("ListRecentChatLogs() error = %v", err)
	}
	if len(account) != 1 || account[0].HeroID != "" {
		t.Fatalf("ListRecentChatLogs() = %+v, want only the account-scope row", account)
	}

	hero, err := st.ListRecentHeroChatLogs(ctx, 7, "xiaoxing", 10)
	if err != nil {
		t.Fatalf("ListRecentHeroChatLogs() error = %v", err)
	}
	if len(hero) != 2 || hero[0].Content != "小星你好" || hero[1].Content != "你好呀" {
		t.Fatalf("ListRecentHeroChatLogs(7, xiaoxing) = %+v, want user 7's two hero rows in order", hero)
	}

	crossHero, err := st.ListRecentHeroChatLogs(ctx, 7, "tutu", 10)
	if err != nil {
		t.Fatalf("ListRecentHeroChatLogs(7, tutu) error = %v", err)
	}
	if len(crossHero) != 0 {
		t.Fatalf("ListRecentHeroChatLogs(7, tutu) = %+v, want empty", crossHero)
	}

	if _, err := st.ListRecentHeroChatLogs(ctx, 7, "", 10); err == nil {
		t.Fatal("ListRecentHeroChatLogs(7, \"\") error = nil, want error for empty hero id")
	}
}
