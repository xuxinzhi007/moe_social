package moebiz

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/pkg/moe/runtime"

	"gorm.io/gorm"
)

// UpsertRuntimeParams 管理端创建/更新 Bot 运行时参数。
type UpsertRuntimeParams struct {
	AgentKey          string
	DisplayName       string
	BotUserID         uint
	CapabilityTier    string
	ModelName         string
	ProviderProfileID string
	ToolsEnabled      bool
	PostQuotaDaily    int
	Enabled           bool
	SystemPrompt      string
	PostRules         string
	ForbiddenTags     string
	PreferredTags     string
	PostScheduleMode  string
	ScheduleCron      string
}

// ListRuntimes 列出全部 Bot 运行时。
func ListRuntimes(ctx context.Context, db *gorm.DB) ([]model.MoeAgentRuntime, error) {
	_ = ctx
	return runtime.ListRuntimes(db)
}

// UpsertRuntime 创建或更新 Bot 运行时，并标记 bot 用户。
func UpsertRuntime(ctx context.Context, db *gorm.DB, p UpsertRuntimeParams) (model.MoeAgentRuntime, error) {
	_ = ctx
	if db == nil {
		return model.MoeAgentRuntime{}, fmt.Errorf("数据库未就绪")
	}
	if p.BotUserID == 0 {
		return model.MoeAgentRuntime{}, fmt.Errorf("无效的 bot_user_id")
	}
	tier := strings.TrimSpace(p.CapabilityTier)
	if tier == "" {
		tier = "s2"
	}
	quota := p.PostQuotaDaily
	if quota <= 0 {
		quota = 5
	}
	rt := &model.MoeAgentRuntime{
		AgentKey:          strings.TrimSpace(p.AgentKey),
		DisplayName:       strings.TrimSpace(p.DisplayName),
		BotUserID:         p.BotUserID,
		CapabilityTier:    tier,
		ModelName:         strings.TrimSpace(p.ModelName),
		ProviderProfileID: strings.TrimSpace(p.ProviderProfileID),
		ToolsEnabled:      p.ToolsEnabled,
		PostQuotaDaily:    quota,
		Enabled:           p.Enabled,
		SystemPrompt:      strings.TrimSpace(p.SystemPrompt),
		PostRules:         strings.TrimSpace(p.PostRules),
		ForbiddenTags:     strings.TrimSpace(p.ForbiddenTags),
		PreferredTags:     strings.TrimSpace(p.PreferredTags),
		PostScheduleMode:  runtime.NormalizeScheduleMode(p.PostScheduleMode),
		ScheduleCron:      strings.TrimSpace(p.ScheduleCron),
	}
	if err := runtime.UpsertRuntime(db, rt); err != nil {
		return model.MoeAgentRuntime{}, err
	}
	_ = db.Model(&model.User{}).Where("id = ?", p.BotUserID).Updates(map[string]any{
		"is_bot":        true,
		"bot_agent_key": rt.AgentKey,
	}).Error
	var saved model.MoeAgentRuntime
	_ = db.Where("agent_key = ?", rt.AgentKey).First(&saved).Error
	return saved, nil
}

// ParseBotUserID 解析管理端 bot_user_id 字符串。
func ParseBotUserID(raw string) (uint, error) {
	v, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil || v == 0 {
		return 0, fmt.Errorf("无效的 bot_user_id")
	}
	return uint(v), nil
}
