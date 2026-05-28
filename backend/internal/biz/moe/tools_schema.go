package moebiz

import (
	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"
)

// ToolsSchemaResult OpenAI 工具 schema 列表。
type ToolsSchemaResult struct {
	Tools []interface{}
	Tier  string
}

// ToolsSchema 返回默认 tier 下的 OpenAI 工具 schema。
func ToolsSchema() ToolsSchemaResult {
	rawTools := tools.OpenAISchemaList()
	toolsOut := make([]interface{}, 0, len(rawTools))
	for _, item := range rawTools {
		toolsOut = append(toolsOut, item)
	}
	return ToolsSchemaResult{
		Tools: toolsOut,
		Tier:  string(core.DefaultTier),
	}
}
