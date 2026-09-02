package aibiz

import (
	"context"
	"fmt"
	"strings"

	llmv1 "backend/api/llm/v1"
	"backend/model"

	"gorm.io/gorm"
)

// GetAiUserConfig 读取用户 AI 配置（persona、preferences 与已同步的 Provider 密钥）。
func GetAiUserConfig(ctx context.Context, store AiStore, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
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
	providerKeys, err := decodeProviderAPIKeys(cfg.ProviderApiKeysEncrypted)
	if err != nil {
		return nil, fmt.Errorf("decrypt ai provider keys: %w", err)
	}
	providerKeysJSON, err := providerAPIKeysJSON(providerKeys)
	if err != nil {
		return nil, err
	}
	return &llmv1.GetAiUserConfigResp{
		UserPersona:         cfg.UserPersona,
		PreferencesJson:     cfg.PreferencesJSON,
		ProviderApiKeysJson: providerKeysJSON,
	}, nil
}

// UpsertAiUserConfig 更新用户 AI 配置。
func UpsertAiUserConfig(ctx context.Context, store AiStore, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	var providerKeys map[string]string
	cfg, err := store.UpdateConfig(ctx, userID, func(config *model.AiUserConfig) error {
		if in.GetHasUserPersona() {
			config.UserPersona = in.GetUserPersona()
		}
		if in.GetPreferencesJson() != "" {
			config.PreferencesJSON = in.GetPreferencesJson()
		}
		var err error
		providerKeys, err = decodeProviderAPIKeys(config.ProviderApiKeysEncrypted)
		if err != nil {
			return fmt.Errorf("decrypt ai provider keys: %w", err)
		}
		if !in.GetHasProviderApiKey() {
			return nil
		}
		profileID := strings.TrimSpace(in.GetProviderApiKeyProfileId())
		if profileID == "" {
			return fmt.Errorf("provider_api_key_profile_id is required")
		}
		apiKey := normalizeProviderAPIKey(in.GetProviderApiKey())
		if apiKey == "" {
			delete(providerKeys, profileID)
		} else {
			providerKeys[profileID] = apiKey
		}
		config.ProviderApiKeysEncrypted, err = encodeProviderAPIKeys(providerKeys)
		if err != nil {
			return fmt.Errorf("encrypt ai provider keys: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("update ai user config: %w", err)
	}
	providerKeysJSON, err := providerAPIKeysJSON(providerKeys)
	if err != nil {
		return nil, err
	}
	return &llmv1.UpsertAiUserConfigResp{
		UserPersona:         cfg.UserPersona,
		PreferencesJson:     cfg.PreferencesJSON,
		ProviderApiKeysJson: providerKeysJSON,
	}, nil
}
