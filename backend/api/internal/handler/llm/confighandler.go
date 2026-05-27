package llm

import (
	"net/http"

	logic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// ConfigHandler 返回后端当前生效的 LLM 配置和记忆预算参数。
func ConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if svcCtx != nil && svcCtx.LLMApp != nil {
			snap := svcCtx.LLMApp.ConfigSnapshot()
			budget := snap.MemoryBudget
			inference := map[string]interface{}{
				"base_url":           snap.InferenceBaseURL,
				"api_style":          snap.InferenceAPIStyle,
				"timeout_seconds":    snap.InferenceTimeoutSec,
				"memory_model":       snap.MemoryModel,
				"has_summary_prompt": snap.HasSummaryPrompt,
				"has_extract_prompt": snap.HasExtractPrompt,
			}
			data := map[string]interface{}{
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
			httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
				"code":    200,
				"message": "获取 LLM 配置成功",
				"success": true,
				"data":    data,
			})
			return
		}

		budget := logic.CurrentMemoryBudgetConfig()
		inference := map[string]interface{}{
			"base_url":           svcCtx.Config.LLMInference.BaseUrl,
			"api_style":          svcCtx.Config.LLMInference.ApiStyle,
			"timeout_seconds":    svcCtx.Config.LLMInference.TimeoutSeconds,
			"memory_model":       svcCtx.Config.LLMInference.MemoryModel,
			"has_summary_prompt": svcCtx.Config.LLMInference.MemorySummaryPrompt != "",
			"has_extract_prompt": svcCtx.Config.LLMInference.MemoryExtractPrompt != "",
		}
		data := map[string]interface{}{
			"llm_inference": inference,
			"ollama":        inference, // 遗留键，App 仍可读；新代码请用 llm_inference
			"memory_budget": budget,
			"local_models": map[string]interface{}{
				"storage_dir":   svcCtx.Config.LocalModels.StorageDir,
				"catalog_count": len(svcCtx.Config.LocalModels.Catalog),
			},
			"runtime": map[string]interface{}{
				"server_memory_enabled": true,
				"raw_debug_only":        true,
				"local_gguf_download":   true,
			},
		}

		httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
			"code":    200,
			"message": "获取 LLM 配置成功",
			"success": true,
			"data":    data,
		})
	}
}
