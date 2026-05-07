package llm

type MemoryBudgetConfig struct {
	MaxInjectedMemoryItems int     `json:"max_injected_memory_items"`
	MaxInjectedMemoryRunes int     `json:"max_injected_memory_runes"`
	MaxHistoryMessages     int     `json:"max_history_messages"`
	KeepRecentMessages     int     `json:"keep_recent_messages"`
	MaxCtxTokens           int     `json:"max_ctx_tokens"`
	CtxSafeRatio           float64 `json:"ctx_safe_ratio"`
}

func CurrentMemoryBudgetConfig() MemoryBudgetConfig {
	return MemoryBudgetConfig{
		MaxInjectedMemoryItems: maxInjectedMemoryItems,
		MaxInjectedMemoryRunes: maxInjectedMemoryRunes,
		MaxHistoryMessages:     maxHistoryMessages,
		KeepRecentMessages:     keepRecentMessages,
		MaxCtxTokens:           maxCtxTokens,
		CtxSafeRatio:           ctxSafeRatio,
	}
}
