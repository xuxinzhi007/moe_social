package llmbiz

// MemoryBudgetConfig 记忆注入预算（与 api/logic/llm 常量对齐）。
type MemoryBudgetConfig struct {
	MaxInjectedMemoryItems int
	MaxInjectedMemoryRunes int
	MaxHistoryMessages     int
	KeepRecentMessages     int
	MaxCtxTokens           int
	CtxSafeRatio           float64
}

// DefaultMemoryBudget 返回默认记忆预算。
func DefaultMemoryBudget() MemoryBudgetConfig {
	return MemoryBudgetConfig{
		MaxInjectedMemoryItems: 8,
		MaxInjectedMemoryRunes: 520,
		MaxHistoryMessages:     40,
		KeepRecentMessages:     16,
		MaxCtxTokens:           4096,
		CtxSafeRatio:           0.7,
	}
}

// ConfigSnapshot LLM 配置快照（供 GET /api/llm/config）。
type ConfigSnapshot struct {
	InferenceBaseURL       string
	InferenceAPIStyle      string
	InferenceTimeoutSec    int
	MemoryModel            string
	HasSummaryPrompt       bool
	HasExtractPrompt       bool
	LocalModelsStorageDir  string
	LocalModelsCatalogSize int
	MemoryBudget           MemoryBudgetConfig
}
