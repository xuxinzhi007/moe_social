package logic

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"

	"gorm.io/gorm"
)

func parseAIUserID(raw string) (uint, error) {
	if strings.TrimSpace(raw) == "" {
		return 0, errorx.InvalidArgument("user_id不能为空")
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return 0, errorx.InvalidArgument("无效的user_id")
	}
	return uint(value), nil
}

func loadOrCreateAIConfig(db *gorm.DB, userID uint) (*model.AiUserConfig, error) {
	var cfg model.AiUserConfig
	err := db.Where("user_id = ?", userID).First(&cfg).Error
	if err == nil {
		return &cfg, nil
	}
	if err != gorm.ErrRecordNotFound {
		return nil, err
	}
	cfg = model.AiUserConfig{
		UserID:               userID,
		ProviderProfilesJSON: "[]",
		AgentsJSON:           "[]",
		LorebooksJSON:        "[]",
		UserPersona:          "",
		PreferencesJSON:      "{}",
	}
	if err := db.Create(&cfg).Error; err != nil {
		return nil, err
	}
	return &cfg, nil
}

func decodeAIJSONArray(raw string) []map[string]interface{} {
	if raw == "" {
		return []map[string]interface{}{}
	}
	var out []map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return []map[string]interface{}{}
	}
	return out
}

func encodeAIJSONArray(items []map[string]interface{}) (string, error) {
	if items == nil {
		items = []map[string]interface{}{}
	}
	raw, err := json.Marshal(items)
	if err != nil {
		return "", errorx.Internal(fmt.Sprintf("encode AI resource json failed: %v", err))
	}
	return string(raw), nil
}
