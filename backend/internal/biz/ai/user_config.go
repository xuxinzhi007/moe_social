package aibiz

import (
	"context"
	"fmt"

	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// GetAiUserConfig 读取用户 AI 配置（persona + preferences JSON）。
func GetAiUserConfig(ctx context.Context, store AiStore, in *moe.GetAiUserConfigReq) (*moe.GetAiUserConfigResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("read ai user config: %w", err)
	}
	return &moe.GetAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}

// UpsertAiUserConfig 更新用户 AI 配置。
func UpsertAiUserConfig(ctx context.Context, store AiStore, in *moe.UpsertAiUserConfigReq) (*moe.UpsertAiUserConfigResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("read ai user config: %w", err)
	}
	if in.GetHasUserPersona() {
		cfg.UserPersona = in.GetUserPersona()
	}
	if in.GetPreferencesJson() != "" {
		cfg.PreferencesJSON = in.GetPreferencesJson()
	}
	if err := store.SaveConfig(ctx, cfg); err != nil {
		return nil, fmt.Errorf("save ai user config: %w", err)
	}
	return &moe.UpsertAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}
