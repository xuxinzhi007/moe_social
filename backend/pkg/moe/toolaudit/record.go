package toolaudit

import (
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"

	"gorm.io/gorm"
)

// RecordInput 单次工具调用埋点入参。
type RecordInput struct {
	Tool             string
	ArgumentsJSON    string
	ActorUserID      uint
	BotUserID        uint
	AgentKey         string
	Ok               bool
	ErrorMsg         string
	LatencyMs        int
	Source           string
	IdempotencyKey   string
}

// Record 异步安全地写入调用记录（失败仅打日志，不影响主流程）。
func Record(db *gorm.DB, in RecordInput) {
	if db == nil {
		return
	}
	tool := strings.TrimSpace(in.Tool)
	if tool == "" {
		return
	}
	src := strings.TrimSpace(in.Source)
	if src == "" {
		src = "api"
	}
	preview := strings.TrimSpace(in.ArgumentsJSON)
	if len(preview) > 240 {
		preview = preview[:240] + "…"
	}
	row := model.MoeToolCall{
		Tool:             tool,
		ActorUserID:      in.ActorUserID,
		BotUserID:        in.BotUserID,
		AgentKey:         strings.TrimSpace(in.AgentKey),
		Ok:               in.Ok,
		ErrorMsg:         truncate(in.ErrorMsg, 500),
		LatencyMs:        in.LatencyMs,
		Source:           src,
		IdempotencyKey:   strings.TrimSpace(in.IdempotencyKey),
		ArgumentsPreview: preview,
		CreatedAt:        time.Now(),
	}
	_ = db.Create(&row).Error
}

func truncate(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(s) <= max {
		return s
	}
	return s[:max]
}

// SchemaItem 管理台展示的工具定义项。
type SchemaItem struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	AllowedTiers []string `json:"allowed_tiers"`
}

// BuildSchemaItems 生成各档位允许的工具说明。
func BuildSchemaItems() []SchemaItem {
	raw := tools.OpenAISchemaList()
	tiers := []core.CapabilityTier{core.TierS0, core.TierS1, core.TierS2, core.TierS3}
	out := make([]SchemaItem, 0, len(raw))
	for _, item := range raw {
		fn, _ := item["function"].(map[string]any)
		if fn == nil {
			continue
		}
		name, _ := fn["name"].(string)
		desc, _ := fn["description"].(string)
		allowed := make([]string, 0, 4)
		for _, t := range tiers {
			if t.AllowsTool(name) {
				allowed = append(allowed, string(t))
			}
		}
		out = append(out, SchemaItem{
			Name:         name,
			Description:  desc,
			AllowedTiers: allowed,
		})
	}
	return out
}
