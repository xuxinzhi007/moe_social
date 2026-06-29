package tools

import "backend/pkg/moe/core"

func allSchemas() []core.ToolSchema {
	return []core.ToolSchema{
		{
			Name:        "post_search",
			Description: "在站内公开动态中检索（关键词 + 可解释排序）。",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"query":    map[string]any{"type": "string"},
					"limit":    map[string]any{"type": "integer"},
					"mood_tag": map[string]any{"type": "string"},
				},
				"required": []string{"query"},
			},
		},
		{
			Name:        "post_get",
			Description: "按 post_id 获取动态摘要。",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"post_id": map[string]any{"type": "string"},
				},
				"required": []string{"post_id"},
			},
		},
		{
			Name:        "post_create",
			Description: "以 Bot 身份发布社区动态（受日配额与审核策略约束）。",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"content":   map[string]any{"type": "string"},
					"mood_tag":  map[string]any{"type": "string"},
				},
				"required": []string{"content"},
			},
		},
		{
			Name:        "brain_refine_episode",
			Description: "润色单条 Bot 自传/记忆：低分或未认可时调用 LLM 改写，并同步更新记忆库与关联动态。",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"episode_id":   map[string]any{"type": "integer", "description": "自传记录 ID"},
					"max_attempts": map[string]any{"type": "integer", "description": "最多润色次数，默认 5"},
				},
				"required": []string{"episode_id"},
			},
		},
		{
			Name:        "brain_curate_memories",
			Description: "批量整理 Bot 低分/未认可记忆，逐条润色直到被认可或达上限。",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"agent_key":    map[string]any{"type": "string", "description": "Bot agent_key"},
					"max_episodes": map[string]any{"type": "integer", "description": "最多处理条数，默认 10"},
					"max_attempts": map[string]any{"type": "integer", "description": "每条最多润色次数，默认 5"},
					"min_quality":  map[string]any{"type": "integer", "description": "低于此分数才处理，默认 70"},
					"force":        map[string]any{"type": "boolean", "description": "是否强制全部重润"},
				},
			},
		},
	}
}

// OpenAISchemaList 转为 API 下发的 tools 数组。
func OpenAISchemaList() []map[string]any {
	schemas := allSchemas()
	out := make([]map[string]any, 0, len(schemas))
	for _, s := range schemas {
		out = append(out, map[string]any{
			"type": "function",
			"function": map[string]any{
				"name":        s.Name,
				"description": s.Description,
				"parameters":  s.Parameters,
			},
		})
	}
	return out
}
