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
		budget := logic.CurrentMemoryBudgetConfig()
		inference := map[string]interface{}{
			"base_url":           svcCtx.Config.Ollama.BaseUrl,
			"api_style":          svcCtx.Config.Ollama.ApiStyle,
			"timeout_seconds":    svcCtx.Config.Ollama.TimeoutSeconds,
			"memory_model":       svcCtx.Config.Ollama.MemoryModel,
			"has_summary_prompt": svcCtx.Config.Ollama.MemorySummaryPrompt != "",
			"has_extract_prompt": svcCtx.Config.Ollama.MemoryExtractPrompt != "",
		}
		data := map[string]interface{}{
			"llm_inference": inference,
			// 兼容旧版 App 字段名
			"ollama": inference,
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
