package gamebiz

import (
	"context"
	"encoding/json"
	"strings"

	"backend/model"
)

// loadLorebookBlock 从用户 AI 配置注入匹配的世界观条目（P4）。
func loadLorebookBlock(ctx context.Context, st Store, userID uint, sceneName, action string) string {
	if st == nil {
		return ""
	}
	db := st.Raw()
	if db == nil {
		return ""
	}
	var cfg model.AiUserConfig
	if err := db.WithContext(ctx).Where("user_id = ?", userID).First(&cfg).Error; err != nil {
		return ""
	}
	raw := strings.TrimSpace(cfg.LorebooksJSON)
	if raw == "" || raw == "[]" {
		return ""
	}
	var books []map[string]interface{}
	if json.Unmarshal([]byte(raw), &books) != nil || len(books) == 0 {
		return ""
	}
	corpus := sceneName + " " + action
	var matched []string
	for _, book := range books {
		name, _ := book["name"].(string)
		desc, _ := book["description"].(string)
		if desc != "" && keywordHit(corpus, name+" "+desc) {
			matched = append(matched, desc)
		}
		entries, _ := book["entries"].([]interface{})
		for _, e := range entries {
			entry, ok := e.(map[string]interface{})
			if !ok {
				continue
			}
			keys, _ := entry["keys"].([]interface{})
			content, _ := entry["content"].(string)
			if content == "" {
				continue
			}
			for _, k := range keys {
				key, _ := k.(string)
				if key != "" && strings.Contains(corpus, key) {
					matched = append(matched, content)
					break
				}
			}
		}
		if len(matched) >= 3 {
			break
		}
	}
	if len(matched) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【世界观设定（lorebook）】\n")
	for i, m := range matched {
		if i >= 3 {
			break
		}
		b.WriteString("- ")
		b.WriteString(strings.TrimSpace(m))
		b.WriteString("\n")
	}
	return b.String()
}

func keywordHit(corpus, text string) bool {
	text = strings.TrimSpace(text)
	if text == "" {
		return false
	}
	for _, part := range strings.Fields(text) {
		if len([]rune(part)) >= 2 && strings.Contains(corpus, part) {
			return true
		}
	}
	return false
}
