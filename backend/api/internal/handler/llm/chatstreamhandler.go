package llm

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	llmlogic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// ChatStreamHandler 提供 SSE（text/event-stream）流式输出接口：
// POST /api/llm/chat/stream
//
// - 请求体与 /api/llm/chat 相同
// - 返回为 SSE：每个事件为 data: {"delta":"...","done":false}\n\n
// - 结束会发送 done=true
func ChatStreamHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	type ollamaStreamChunk struct {
		Message struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"message"`
		Done bool `json:"done"`
	}

	type sseData struct {
		Delta string `json:"delta"`
		Done  bool   `json:"done"`
	}

	writeSse := func(w http.ResponseWriter, payload any) error {
		b, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		if _, err := fmt.Fprintf(w, "data: %s\n\n", string(b)); err != nil {
			return err
		}
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
		return nil
	}

	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LlmChatReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// SSE 必需的响应头
		h := w.Header()
		h.Set("Content-Type", "text/event-stream; charset=utf-8")
		h.Set("Cache-Control", "no-cache")
		h.Set("Connection", "keep-alive")
		// 部分反代会缓存/缓冲，这里提示禁用（不保证所有反代都遵守）
		h.Set("X-Accel-Buffering", "no")

		logic := llmlogic.NewChatStreamLogic(r.Context(), svcCtx)
		body, err := logic.Stream(&req)
		if err != nil {
			// 用 SSE 形式返回错误，便于前端统一处理
			_ = writeSse(w, map[string]any{
				"error": err.Error(),
				"done":  true,
			})
			return
		}
		defer body.Close()

		scanner := bufio.NewScanner(body)
		// Ollama 的单行 JSON 可能超过默认 64K，手动调大 buffer
		scanner.Buffer(make([]byte, 0, 64*1024), 2*1024*1024)

		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}

			var chunk ollamaStreamChunk
			if err := json.Unmarshal([]byte(line), &chunk); err != nil {
				// 某些情况下可能出现非 JSON 行，忽略即可
				continue
			}

			// Ollama 的 message.content 是增量内容（每次只包含新增的字符）
			// 需要累积发送给前端
			if chunk.Message.Content != "" {
				// 直接发送增量内容，前端会累积
				if err := writeSse(w, sseData{Delta: chunk.Message.Content, Done: false}); err != nil {
					return
				}
			}
			if chunk.Done {
				_ = writeSse(w, sseData{Delta: "", Done: true})
				return
			}
		}
		
		// 如果扫描结束但没收到 done，也发送结束标记
		if scanner.Err() == nil {
			_ = writeSse(w, sseData{Delta: "", Done: true})
		}

		// 扫描结束（可能是连接断开/超时），尽量通知前端结束
		_ = writeSse(w, sseData{Delta: "", Done: true})
	}
}


