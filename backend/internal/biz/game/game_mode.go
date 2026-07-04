package gamebiz

import "strings"

// 游戏 LLM 模式：
// - narrator：Go 管世界 + 工具/规则改 DB，小模型只写叙事（适合 0.5B～3B）
// - agent：模型通过 JSON 调 world_* 工具（适合 7B+ 且 JSON 稳定）
const (
	GameLlmModeNarrator = "narrator"
	GameLlmModeAgent    = "agent"
)

func ResolveGameLlmMode(configured, modelName string) string {
	switch strings.ToLower(strings.TrimSpace(configured)) {
	case GameLlmModeAgent, "orchestrator":
		return GameLlmModeAgent
	case GameLlmModeNarrator:
		return GameLlmModeNarrator
	}
	// 未配置：按模型体量自动选择
	lower := strings.ToLower(modelName)
	if strings.Contains(lower, "0.5") || strings.Contains(lower, "1b") || strings.Contains(lower, "1.5b") {
		return GameLlmModeNarrator
	}
	if strings.Contains(lower, "3b") {
		return GameLlmModeNarrator
	}
	return GameLlmModeNarrator
}

func IsAgentMode(deps TurnDeps) bool {
	return deps.LlmMode == GameLlmModeAgent
}

func IsNarratorMode(deps TurnDeps) bool {
	return !IsAgentMode(deps)
}
