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
		data := map[string]interface{}{
			"ollama": map[string]interface{}{
				"base_url":           svcCtx.Config.Ollama.BaseUrl,
				"timeout_seconds":    svcCtx.Config.Ollama.TimeoutSeconds,
				"memory_model":       svcCtx.Config.Ollama.MemoryModel,
				"has_summary_prompt": svcCtx.Config.Ollama.MemorySummaryPrompt != "",
				"has_extract_prompt": svcCtx.Config.Ollama.MemoryExtractPrompt != "",
			},
			"memory_budget": budget,
		}

		httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
			"code":    200,
			"message": "获取 LLM 配置成功",
			"success": true,
			"data":    data,
		})
	}
}
