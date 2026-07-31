package companionapp

import (
	"context"
	"errors"
	"fmt"
	"strings"

	companionbiz "backend/internal/biz/companion"
	"backend/model"

	"gorm.io/gorm"
)

// ensureCommunityBot 保证伙伴有可发帖的 bot 用户：无则创建，有则同步展示名/头像。
func (s *AppService) ensureCommunityBot(
	ctx context.Context,
	ownerUserID uint,
	profile *companionbiz.Profile,
) (*model.User, string, error) {
	if s == nil || s.db == nil || profile == nil {
		return nil, "", nil
	}

	agentID := strings.TrimSpace(profile.AgentID)
	if agentID == "" {
		agentID = fmt.Sprintf("companion-%d", ownerUserID)
		profile.AgentID = agentID
		engine, err := s.requireEngine()
		if err == nil && engine != nil {
			_, _ = engine.UpsertProfile(ctx, ownerUserID, profile)
		}
	}

	var botUser model.User
	err := s.db.WithContext(ctx).
		Where("is_bot = ? AND bot_agent_key = ?", true, agentID).
		First(&botUser).Error
	if err == nil {
		s.syncCommunityBotAppearance(ctx, &botUser, profile)
		return &botUser, agentID, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, "", fmt.Errorf("lookup companion bot for agent %s: %w", agentID, err)
	}

	displayName := strings.TrimSpace(profile.Name)
	if displayName == "" {
		displayName = "AI伙伴"
	}
	username := fmt.Sprintf("bot_c_%d", ownerUserID)
	email := fmt.Sprintf("companion-%d@bot.local", ownerUserID)
	avatar := strings.TrimSpace(profile.AvatarURL)

	botUser = model.User{
		Username:    username,
		Email:       email,
		Password:    fmt.Sprintf("bot-companion-%d-no-login", ownerUserID),
		Avatar:      avatar,
		Signature:   strings.TrimSpace(profile.Persona),
		IsBot:       true,
		BotAgentKey: agentID,
		Role:        "user",
	}
	if err := s.db.WithContext(ctx).Create(&botUser).Error; err != nil {
		// 并发创建时再查一次。
		var existing model.User
		if findErr := s.db.WithContext(ctx).
			Where("is_bot = ? AND bot_agent_key = ?", true, agentID).
			First(&existing).Error; findErr == nil {
			s.syncCommunityBotAppearance(ctx, &existing, profile)
			return &existing, agentID, nil
		}
		return nil, "", fmt.Errorf("create companion bot for agent %s: %w", agentID, err)
	}
	return &botUser, agentID, nil
}

func (s *AppService) syncCommunityBotAppearance(
	ctx context.Context,
	bot *model.User,
	profile *companionbiz.Profile,
) {
	if s == nil || s.db == nil || bot == nil || profile == nil {
		return
	}
	updates := map[string]interface{}{}
	avatar := strings.TrimSpace(profile.AvatarURL)
	if avatar != "" && strings.TrimSpace(bot.Avatar) != avatar {
		updates["avatar"] = avatar
	}
	persona := strings.TrimSpace(profile.Persona)
	if persona != "" && strings.TrimSpace(bot.Signature) != persona {
		updates["signature"] = truncateRunes(persona, 100)
	}
	if len(updates) == 0 {
		return
	}
	_ = s.db.WithContext(ctx).Model(bot).Updates(updates).Error
	if v, ok := updates["avatar"].(string); ok {
		bot.Avatar = v
	}
	if v, ok := updates["signature"].(string); ok {
		bot.Signature = v
	}
}

func truncateRunes(s string, max int) string {
	if max <= 0 || s == "" {
		return s
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max])
}
