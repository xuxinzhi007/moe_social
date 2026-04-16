package llm

import (
	"io"
	"net/http"
	"strings"

	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// ChatRawHandler forwards request body to Ollama `/api/chat` and returns the raw response.
// This keeps behavior close to terminal usage (no memory/system injection/summarization on server side).
//
// 当请求 JSON 里 "stream": true 时，Ollama 返回 NDJSON 分块；此处用流式拷贝 + Flush，
// 避免先把整段回答读进内存再一次性下发，便于 Flutter 端做打字机效果。
func ChatRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		baseUrl := strings.TrimRight(svcCtx.Config.Ollama.BaseUrl, "/")
		if baseUrl == "" {
			baseUrl = "http://127.0.0.1:11434"
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 流式响应可能持续数分钟：不要用「整次读 body」的全局 Timeout，否则长对话会被掐断。
		// 取消/上限交给 r.Context()（客户端断开即中止）。
		client := &http.Client{
			Timeout: 0,
		}

		req, err := http.NewRequestWithContext(
			r.Context(), http.MethodPost, baseUrl+"/api/chat", strings.NewReader(string(body)))
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		req.Header.Set("Content-Type", "application/json; charset=utf-8")

		resp, err := client.Do(req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer resp.Body.Close()

		if ct := resp.Header.Get("Content-Type"); ct != "" {
			w.Header().Set("Content-Type", ct)
		} else {
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
		}
		w.WriteHeader(resp.StatusCode)

		flusher, _ := w.(http.Flusher)
		buf := make([]byte, 16*1024)
		for {
			n, readErr := resp.Body.Read(buf)
			if n > 0 {
				if _, werr := w.Write(buf[:n]); werr != nil {
					return
				}
				if flusher != nil {
					flusher.Flush()
				}
			}
			if readErr == io.EOF {
				break
			}
			if readErr != nil {
				return
			}
		}
	}
}

