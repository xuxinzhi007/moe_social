package llm

import (
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// ShowRawHandler proxies POST /api/show to Ollama and returns the raw response.
// Used by the app to read a model's Modelfile / system prompt.
func ShowRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		timeoutSeconds := svcCtx.Config.Ollama.TimeoutSeconds
		if timeoutSeconds <= 0 {
			timeoutSeconds = 15
		}

		baseUrl, err := common.ResolveOllamaBaseURL(svcCtx.Config.Ollama.BaseUrl)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
		req, err := http.NewRequestWithContext(
			r.Context(), http.MethodPost,
			baseUrl+"/api/show",
			strings.NewReader(string(body)),
		)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		common.ApplyOllamaForwardHeaders(req)
		req.Header.Set("Content-Type", "application/json; charset=utf-8")

		resp, err := client.Do(req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer resp.Body.Close()

		raw, _ := io.ReadAll(resp.Body)
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(resp.StatusCode)
		_, _ = w.Write(raw)
	}
}
