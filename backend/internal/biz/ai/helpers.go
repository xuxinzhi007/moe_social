package aibiz

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/model"
)

// ParseUserID 解析 AI 资源 user_id。
func ParseUserID(raw string) (uint, error) {
	if strings.TrimSpace(raw) == "" {
		return 0, ErrEmptyUserID
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return 0, ErrInvalidUserID
	}
	return uint(value), nil
}

// DecodeJSONArray 解析 AI 配置 JSON 数组。
func DecodeJSONArray(raw string) []map[string]interface{} {
	if raw == "" {
		return []map[string]interface{}{}
	}
	var out []map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return []map[string]interface{}{}
	}
	return out
}

// EncodeJSONArray 序列化 AI 配置 JSON 数组。
func EncodeJSONArray(items []map[string]interface{}) (string, error) {
	if items == nil {
		items = []map[string]interface{}{}
	}
	raw, err := json.Marshal(items)
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrEncodeResource, err)
	}
	return string(raw), nil
}

func selectField(cfg *model.AiUserConfig, field string) string {
	switch field {
	case "providers":
		return cfg.ProviderProfilesJSON
	case "agents":
		return cfg.AgentsJSON
	case "lorebooks":
		return cfg.LorebooksJSON
	default:
		return "[]"
	}
}

func setField(cfg *model.AiUserConfig, field, value string) {
	switch field {
	case "providers":
		cfg.ProviderProfilesJSON = value
	case "agents":
		cfg.AgentsJSON = value
	case "lorebooks":
		cfg.LorebooksJSON = value
	}
}

func mustJSON(v interface{}) (string, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrEncodeResource, err)
	}
	return string(raw), nil
}

// AgentIsPublic 判断 agent JSON 是否公开。
func AgentIsPublic(item map[string]interface{}) bool {
	raw, ok := item["is_public"]
	if !ok {
		return false
	}
	switch v := raw.(type) {
	case bool:
		return v
	case string:
		s := strings.TrimSpace(strings.ToLower(v))
		return s == "true" || s == "1" || s == "yes"
	case float64:
		return v != 0
	case int:
		return v != 0
	case int64:
		return v != 0
	default:
		return false
	}
}

// StringValue 将 JSON 字段转为字符串。
func StringValue(raw interface{}) string {
	if raw == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(raw))
}

// ParseAgentCreatedAt 解析 agent created_at 字段。
func ParseAgentCreatedAt(raw interface{}) time.Time {
	switch v := raw.(type) {
	case nil:
		return time.Now()
	case int64:
		return time.UnixMilli(v)
	case int32:
		return time.UnixMilli(int64(v))
	case int:
		return time.UnixMilli(int64(v))
	case float64:
		return time.UnixMilli(int64(v))
	case float32:
		return time.UnixMilli(int64(v))
	case json.Number:
		if n, err := v.Int64(); err == nil {
			return time.UnixMilli(n)
		}
	case string:
		if n, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64); err == nil {
			return time.UnixMilli(n)
		}
	}
	return time.Now()
}
