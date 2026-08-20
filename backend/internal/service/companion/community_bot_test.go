package companionapp

import (
	"context"
	"testing"

	companionbiz "backend/internal/biz/companion"
	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestEnsureCommunityBotRebindsHistoricalBot(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skipf("sqlite unavailable: %v", err)
	}
	if err := db.AutoMigrate(&model.User{}); err != nil {
		t.Fatalf("migrate users: %v", err)
	}

	historical := model.User{
		Username:    "bot_c_1",
		Email:       "companion-1@bot.local",
		Password:    "historical-bot-password",
		IsBot:       true,
		BotAgentKey: "old-agent",
	}
	if err := db.Create(&historical).Error; err != nil {
		t.Fatalf("create historical bot: %v", err)
	}

	service := &AppService{db: db}
	profile := &companionbiz.Profile{AgentID: "new-agent", Name: "啾啾"}
	bot, agentID, err := service.ensureCommunityBot(context.Background(), 1, profile)
	if err != nil {
		t.Fatalf("ensure community bot: %v", err)
	}
	if bot.ID != historical.ID || agentID != "new-agent" {
		t.Fatalf("unexpected bot identity: id=%d agent=%q", bot.ID, agentID)
	}

	var stored model.User
	if err := db.First(&stored, historical.ID).Error; err != nil {
		t.Fatalf("load rebound bot: %v", err)
	}
	if stored.BotAgentKey != "new-agent" {
		t.Fatalf("bot agent key = %q, want new-agent", stored.BotAgentKey)
	}
}

func TestEnsureCommunityBotDoesNotAdoptRegularUser(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skipf("sqlite unavailable: %v", err)
	}
	if err := db.AutoMigrate(&model.User{}); err != nil {
		t.Fatalf("migrate users: %v", err)
	}

	regular := model.User{
		Username: "bot_c_1",
		Email:    "regular@example.com",
		Password: "regular-user-password",
	}
	if err := db.Create(&regular).Error; err != nil {
		t.Fatalf("create regular user: %v", err)
	}

	service := &AppService{db: db}
	profile := &companionbiz.Profile{AgentID: "new-agent"}
	if _, _, err := service.ensureCommunityBot(context.Background(), 1, profile); err == nil {
		t.Fatal("ensure community bot succeeded with a conflicting regular username")
	}

	var stored model.User
	if err := db.First(&stored, regular.ID).Error; err != nil {
		t.Fatalf("load regular user: %v", err)
	}
	if stored.IsBot || stored.BotAgentKey != "" {
		t.Fatalf("regular user was adopted as bot: %+v", stored)
	}
}
