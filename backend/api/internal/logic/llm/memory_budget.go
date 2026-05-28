package llm

import llmbiz "backend/internal/biz/llm"

type MemoryBudgetConfig struct {
	MaxInjectedMemoryItems int     `json:"max_injected_memory_items"`
	MaxInjectedMemoryRunes int     `json:"max_injected_memory_runes"`
	MaxHistoryMessages     int     `json:"max_history_messages"`
	KeepRecentMessages     int     `json:"keep_recent_messages"`
	MaxCtxTokens           int     `json:"max_ctx_tokens"`
	CtxSafeRatio           float64 `json:"ctx_safe_ratio"`
}

func CurrentMemoryBudgetConfig() MemoryBudgetConfig {
	b := llmbiz.DefaultMemoryBudget()
	return MemoryBudgetConfig{
		MaxInjectedMemoryItems: b.MaxInjectedMemoryItems,
		MaxInjectedMemoryRunes: b.MaxInjectedMemoryRunes,
		MaxHistoryMessages:     b.MaxHistoryMessages,
		KeepRecentMessages:     b.KeepRecentMessages,
		MaxCtxTokens:           b.MaxCtxTokens,
		CtxSafeRatio:           b.CtxSafeRatio,
	}
}
