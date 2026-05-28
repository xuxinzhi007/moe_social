package aibiz

import (
	"context"
	"fmt"

	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// GetAiUserConfig 读取用户 AI 配置（persona + preferences JSON）。
func GetAiUserConfig(ctx context.Context, db *gorm.DB, in *super.GetAiUserConfigReq) (*super.GetAiUserConfigResp, error) {
	if db == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := LoadOrCreateConfig(db.WithContext(ctx), userID)
	if err != nil {
		return nil, fmt.Errorf("read ai user config: %w", err)
	}
	return &super.GetAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}

// UpsertAiUserConfig 更新用户 AI 配置。
func UpsertAiUserConfig(ctx context.Context, db *gorm.DB, in *super.UpsertAiUserConfigReq) (*super.UpsertAiUserConfigResp, error) {
	if db == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := LoadOrCreateConfig(db.WithContext(ctx), userID)
	if err != nil {
		return nil, fmt.Errorf("read ai user config: %w", err)
	}
	if in.GetHasUserPersona() {
		cfg.UserPersona = in.GetUserPersona()
	}
	if in.GetPreferencesJson() != "" {
		cfg.PreferencesJSON = in.GetPreferencesJson()
	}
	if err := db.WithContext(ctx).Save(cfg).Error; err != nil {
		return nil, fmt.Errorf("save ai user config: %w", err)
	}
	return &super.UpsertAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}
