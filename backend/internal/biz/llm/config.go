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

// ConfigAPIPayload 构建 GET /api/llm/config 的 data 字段。
func ConfigAPIPayload(snap ConfigSnapshot) map[string]interface{} {
	budget := snap.MemoryBudget
	inference := map[string]interface{}{
		"base_url":           snap.InferenceBaseURL,
		"api_style":          snap.InferenceAPIStyle,
		"timeout_seconds":    snap.InferenceTimeoutSec,
		"memory_model":       snap.MemoryModel,
		"has_summary_prompt": snap.HasSummaryPrompt,
		"has_extract_prompt": snap.HasExtractPrompt,
	}
	return map[string]interface{}{
		"llm_inference": inference,
		"ollama":        inference,
		"memory_budget": map[string]interface{}{
			"max_injected_memory_items": budget.MaxInjectedMemoryItems,
			"max_injected_memory_runes": budget.MaxInjectedMemoryRunes,
			"max_history_messages":      budget.MaxHistoryMessages,
			"keep_recent_messages":      budget.KeepRecentMessages,
			"max_ctx_tokens":            budget.MaxCtxTokens,
			"ctx_safe_ratio":            budget.CtxSafeRatio,
		},
		"local_models": map[string]interface{}{
			"storage_dir":   snap.LocalModelsStorageDir,
			"catalog_count": snap.LocalModelsCatalogSize,
		},
		"runtime": map[string]interface{}{
			"server_memory_enabled": true,
			"raw_debug_only":        true,
			"local_gguf_download":   true,
		},
	}
}
