package llm

import (
	"bufio"
	"encoding/json"
	"net/http"
	"strings"

	llmlogic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/rest/httpx"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// 允许所有来源（生产环境应该限制）
		return true
	},
}

// ChatWebSocketHandler 提供 WebSocket 流式输出接口：
// WS /api/llm/chat/ws
//
// - 客户端发送 JSON: {"model": "...", "messages": [...]}
// - 服务端持续发送 JSON: {"delta": "...", "done": false}
// - 结束时发送: {"delta": "", "done": true}
func ChatWebSocketHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	type ollamaStreamChunk struct {
		Message struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"message"`
		Done bool `json:"done"`
	}

	type wsMessage struct {
		Delta string `json:"delta"`
		Done  bool   `json:"done"`
		Error string `json:"error,omitempty"`
	}

	return func(w http.ResponseWriter, r *http.Request) {
		// 升级为 WebSocket 连接
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer conn.Close()

		// 读取客户端请求
		var req types.LlmChatReq
		if err := conn.ReadJSON(&req); err != nil {
			// 发送错误并关闭连接
			_ = conn.WriteJSON(wsMessage{
				Error: "读取请求失败: " + err.Error(),
				Done:  true,
			})
			return
		}

		// 调用逻辑层获取流式响应
		logic := llmlogic.NewChatStreamLogic(r.Context(), svcCtx)
		body, err := logic.Stream(&req)
		if err != nil {
			_ = conn.WriteJSON(wsMessage{
				Error: err.Error(),
				Done:  true,
			})
			return
		}
		defer body.Close()

		// 读取 Ollama 流式响应并转发给客户端
		scanner := bufio.NewScanner(body)
		scanner.Buffer(make([]byte, 0, 64*1024), 2*1024*1024)

		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}

			var chunk ollamaStreamChunk
			if err := json.Unmarshal([]byte(line), &chunk); err != nil {
				continue
			}

			// 发送增量内容
			if chunk.Message.Content != "" {
				if err := conn.WriteJSON(wsMessage{
					Delta: chunk.Message.Content,
					Done:  false,
				}); err != nil {
					// 客户端断开连接
					return
				}
			}

			// 流式结束
			if chunk.Done {
				_ = conn.WriteJSON(wsMessage{
					Delta: "",
					Done:  true,
				})
				return
			}
		}

		// 确保发送结束标记
		_ = conn.WriteJSON(wsMessage{
			Delta: "",
			Done:  true,
		})
	}
}
