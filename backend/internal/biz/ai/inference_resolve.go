package aibiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"backend/pkg/llminference"
)

const (
	builtinBackendProviderID     = "builtin_backend_ollama"
	legacyBuiltinLocalProviderID = "builtin_local_llama_cpp"
	activeProviderPreferenceKey  = "last_selected_provider_id"
	activeProviderTimeoutSeconds = 300
)

// ErrActiveProviderUnavailable 表示用户选中的外部供应商缺少地址或模型。
var ErrActiveProviderUnavailable = errors.New("saved provider is missing endpoint or model")

// ResolveActiveInference 按用户已保存的供应商选择构造推理配置。
// 未选择或选择内置后端时返回 nil，调用方继续使用服务端默认推理配置。
func ResolveActiveInference(ctx context.Context, store AiStore, userID uint) (*llminference.Config, error) {
	if store == nil || userID == 0 {
		return nil, nil
	}
	cfg, err := store.WithContext(ctx).LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("load ai user config: %w", err)
	}
	profileID := selectedProviderID(cfg.PreferencesJSON)
	if profileID == "" || isBuiltinProviderID(profileID) {
		return nil, nil
	}
	profile := findProviderProfile(cfg.ProviderProfilesJSON, profileID)
	if profile == nil {
		return nil, ErrActiveProviderUnavailable
	}
	modelName := providerModel(profile)
	baseURL := strings.TrimSpace(fmtString(profile["base_url"]))
	if baseURL == "" || modelName == "" {
		return nil, ErrActiveProviderUnavailable
	}
	keys, err := decodeProviderAPIKeys(cfg.ProviderApiKeysEncrypted)
	if err != nil {
		return nil, fmt.Errorf("decrypt ai provider keys: %w", err)
	}
	resolved := llminference.ConfigFrom(
		baseURL,
		providerAPIStyle(fmtString(profile["provider_type"])),
		activeProviderTimeoutSeconds,
		modelName,
		keys[profileID],
	)
	return &resolved, nil
}

func selectedProviderID(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	var prefs map[string]any
	if err := json.Unmarshal([]byte(raw), &prefs); err != nil {
		return ""
	}
	return strings.TrimSpace(fmtString(prefs[activeProviderPreferenceKey]))
}

func isBuiltinProviderID(id string) bool {
	switch strings.TrimSpace(id) {
	case builtinBackendProviderID, legacyBuiltinLocalProviderID:
		return true
	default:
		return false
	}
}

func findProviderProfile(raw, profileID string) map[string]any {
	for _, item := range DecodeJSONArray(raw) {
		if strings.TrimSpace(fmtString(item["id"])) == profileID {
			return item
		}
	}
	return nil
}

func providerModel(profile map[string]any) string {
	if model := strings.TrimSpace(fmtString(profile["default_model"])); model != "" {
		return model
	}
	raw := strings.TrimSpace(fmtString(profile["manual_models_json"]))
	if raw == "" {
		return ""
	}
	var models []string
	if err := json.Unmarshal([]byte(raw), &models); err != nil {
		return ""
	}
	for _, model := range models {
		model = strings.TrimSpace(model)
		if model != "" {
			return model
		}
	}
	return ""
}

func providerAPIStyle(providerType string) string {
	if strings.EqualFold(strings.TrimSpace(providerType), "backend_ollama") {
		return "ollama"
	}
	return "openai"
}

func fmtString(value any) string {
	if value == nil {
		return ""
	}
	text, ok := value.(string)
	if ok {
		return text
	}
	return fmt.Sprint(value)
}
