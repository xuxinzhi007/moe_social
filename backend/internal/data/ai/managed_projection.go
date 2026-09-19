package aidata

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"backend/model"
	"gorm.io/gorm"
)

// PublicAgent projects a private reference into a copyable base model without leaking managed names.
func (s *store) PublicAgent(ctx context.Context, owner uint, item map[string]any) (map[string]any, error) {
	name, _ := item["model_name"].(string)
	base := ""
	if strings.HasPrefix(strings.ToLower(name), "moe-user-") {
		var row model.LLMManagedModel
		err := s.db.WithContext(ctx).Where("owner_id = ? AND agent_id = ? AND managed_name = ?", owner, fmt.Sprint(item["id"]), name).First(&row).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
		if err == nil {
			base = row.BaseModel
		}
	}
	cleanPrivateRefs(item)
	if name != "" && strings.HasPrefix(strings.ToLower(name), "moe-user-") {
		item["model_name"] = base
	}
	return item, nil
}
func cleanPrivateRefs(item map[string]any) {
	for k, v := range item {
		if strings.HasPrefix(k, "managed_") || k == "request_id" {
			delete(item, k)
			continue
		}
		switch value := v.(type) {
		case string:
			if strings.HasPrefix(strings.ToLower(value), "moe-user-") {
				delete(item, k)
			}
		case map[string]any:
			cleanPrivateRefs(value)
		case []any:
			for i, entry := range value {
				if text, ok := entry.(string); ok && strings.HasPrefix(strings.ToLower(text), "moe-user-") {
					value[i] = nil
				}
				if nested, ok := entry.(map[string]any); ok {
					cleanPrivateRefs(nested)
				}
			}
		}
	}
}
