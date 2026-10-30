package companiondata

import (
	"context"
	"errors"
	"fmt"
	"strings"

	companionbiz "backend/internal/biz/companion"
	"backend/model"

	"gorm.io/gorm"
)

type identityStore struct {
	db *gorm.DB
}

// NewIdentityStore 构造 companionbiz.IdentityStore。
func NewIdentityStore(db *gorm.DB) companionbiz.IdentityStore {
	if db == nil {
		return nil
	}
	return &identityStore{db: db}
}

func (s *identityStore) CreateProactiveNotification(ctx context.Context, userID uint, content string) (uint, error) {
	notice := &model.Notification{
		UserID:  userID,
		Type:    9,
		Content: content,
	}
	if err := s.db.WithContext(ctx).Create(notice).Error; err != nil {
		return 0, err
	}
	return notice.ID, nil
}

func (s *identityStore) MarkProactiveNotificationRead(ctx context.Context, userID, notificationID uint) error {
	var notice model.Notification
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ? AND type = ?", notificationID, userID, 9).
		First(&notice).Error; err != nil {
		return err
	}
	if !notice.IsRead {
		if err := s.db.WithContext(ctx).Model(&model.Notification{}).
			Where("id = ? AND user_id = ? AND type = ?", notificationID, userID, 9).
			Update("is_read", true).Error; err != nil {
			return err
		}
	}
	return nil
}

func (s *identityStore) EnsureCommunityBot(
	ctx context.Context,
	ownerUserID uint,
	agentID, displayName, avatarURL, persona string,
) (*model.User, error) {
	var botUser model.User
	err := s.db.WithContext(ctx).
		Where("is_bot = ? AND bot_agent_key = ?", true, agentID).
		First(&botUser).Error
	if err == nil {
		s.syncCommunityBotAppearance(ctx, &botUser, displayName, avatarURL, persona)
		return &botUser, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("lookup companion bot for agent %s: %w", agentID, err)
	}

	username := fmt.Sprintf("bot_c_%d", ownerUserID)
	email := fmt.Sprintf("companion-%d@bot.local", ownerUserID)
	botUser, err = s.findCommunityBotByStableIdentity(ctx, agentID, username, email)
	if err != nil {
		return nil, err
	}
	if botUser.ID != 0 {
		s.syncCommunityBotAppearance(ctx, &botUser, displayName, avatarURL, persona)
		return &botUser, nil
	}
	avatar := strings.TrimSpace(avatarURL)

	botUser = model.User{
		Username:    username,
		Email:       email,
		Password:    fmt.Sprintf("bot-companion-%d-no-login", ownerUserID),
		Avatar:      avatar,
		Signature:   strings.TrimSpace(persona),
		IsBot:       true,
		BotAgentKey: agentID,
		Role:        "user",
	}
	if err := s.db.WithContext(ctx).Create(&botUser).Error; err != nil {
		existing, findErr := s.findCommunityBotByStableIdentity(ctx, agentID, username, email)
		if findErr != nil {
			return nil, findErr
		}
		if existing.ID != 0 {
			s.syncCommunityBotAppearance(ctx, &existing, displayName, avatarURL, persona)
			return &existing, nil
		}
		return nil, fmt.Errorf("create companion bot for agent %s: %w", agentID, err)
	}
	s.syncCommunityBotAppearance(ctx, &botUser, displayName, avatarURL, persona)
	return &botUser, nil
}

func (s *identityStore) findCommunityBotByStableIdentity(
	ctx context.Context,
	agentID, username, email string,
) (model.User, error) {
	var botUser model.User
	err := s.db.WithContext(ctx).
		Where("is_bot = ? AND bot_agent_key = ?", true, agentID).
		First(&botUser).Error
	if err == nil {
		return botUser, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, fmt.Errorf("lookup companion bot for agent %s: %w", agentID, err)
	}

	err = s.db.WithContext(ctx).
		Where("is_bot = ? AND (username = ? OR email = ?)", true, username, email).
		First(&botUser).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, nil
	}
	if err != nil {
		return model.User{}, fmt.Errorf("lookup historical companion bot for agent %s: %w", agentID, err)
	}
	if strings.TrimSpace(botUser.BotAgentKey) == agentID {
		return botUser, nil
	}
	if err := s.db.WithContext(ctx).
		Model(&botUser).
		Update("bot_agent_key", agentID).Error; err != nil {
		return model.User{}, fmt.Errorf("rebind companion bot for agent %s: %w", agentID, err)
	}
	botUser.BotAgentKey = agentID
	return botUser, nil
}

func (s *identityStore) syncCommunityBotAppearance(
	ctx context.Context,
	bot *model.User,
	displayName, avatarURL, persona string,
) {
	if s == nil || s.db == nil || bot == nil {
		return
	}
	updates := map[string]interface{}{}
	avatar := strings.TrimSpace(avatarURL)
	if avatar != "" && strings.TrimSpace(bot.Avatar) != avatar {
		updates["avatar"] = avatar
	}
	persona = strings.TrimSpace(persona)
	if persona != "" && strings.TrimSpace(bot.Signature) != persona {
		updates["signature"] = truncateRunes(persona, 100)
	}
	if display := companionBotDisplayName(displayName); display != "" && bot.Username != display {
		var taken int64
		if err := s.db.WithContext(ctx).Model(&model.User{}).
			Where("username = ? AND id <> ?", display, bot.ID).
			Count(&taken).Error; err == nil && taken == 0 {
			updates["username"] = display
		}
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
	if v, ok := updates["username"].(string); ok {
		bot.Username = v
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

func companionBotDisplayName(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return ""
	}
	return truncateRunes(name, 50)
}
