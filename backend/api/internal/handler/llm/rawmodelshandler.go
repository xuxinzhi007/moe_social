package llm

import (
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// ModelsRawHandler returns the raw Ollama `/api/tags` response.
// It does NOT wrap the payload into BaseResp to keep output consistent with terminal.
func ModelsRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		timeoutSeconds := svcCtx.Config.Ollama.TimeoutSeconds
		if timeoutSeconds <= 0 {
			timeoutSeconds = 10
		}

		baseUrl := strings.TrimRight(svcCtx.Config.Ollama.BaseUrl, "/")
		if baseUrl == "" {
			baseUrl = "http://127.0.0.1:11434"
		}

		client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
		req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, baseUrl+"/api/tags", nil)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

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

