package llmbiz

// ConfigSnapshot contains safe client capability metadata. Base URL is retained
// for internal compatibility, but never emitted by ConfigAPIPayload.
type ConfigSnapshot struct {
	InferenceBaseURL        string
	InferenceAPIStyle       string
	InferenceTimeoutSec     int
	MemoryModel             string
	HasSummaryPrompt        bool
	HasExtractPrompt        bool
	MemoryBudget            MemoryBudgetConfig
	SupportsModelManagement bool
	ModelSyncTimeoutSeconds int
}
type MemoryBudgetConfig struct {
	MaxCtxTokens       int
	CtxSafeRatio       float64
	MaxHistoryMessages int
	KeepRecentMessages int
}

func DefaultMemoryBudget() MemoryBudgetConfig { return MemoryBudgetConfig{8192, 0.75, 40, 12} }
func ConfigAPIPayload(cfg ConfigSnapshot) map[string]interface{} {
	return map[string]interface{}{
		"inference_api_style":        cfg.InferenceAPIStyle,
		"inference_timeout_sec":      cfg.InferenceTimeoutSec,
		"supports_model_management":  cfg.SupportsModelManagement,
		"model_sync_timeout_seconds": cfg.ModelSyncTimeoutSeconds,
		"memory_model":               cfg.MemoryModel,
		"has_summary_prompt":         cfg.HasSummaryPrompt,
		"has_extract_prompt":         cfg.HasExtractPrompt,
		"memory_budget":              map[string]interface{}{"max_ctx_tokens": cfg.MemoryBudget.MaxCtxTokens, "ctx_safe_ratio": cfg.MemoryBudget.CtxSafeRatio, "max_history_messages": cfg.MemoryBudget.MaxHistoryMessages, "keep_recent_messages": cfg.MemoryBudget.KeepRecentMessages},
	}
}

type PlatformWriteResult struct {
	Code    int
	Message string
	Success bool
}
type CreateAgentInput struct{ AgentID, RequestID, Name, BaseModel, SystemPrompt string }
type ModelCacheClearer interface{ Clear() }
