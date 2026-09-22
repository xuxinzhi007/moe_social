package llmhttp

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	llmbiz "backend/internal/biz/llm"
	llmapp "backend/internal/service/llm"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const maxChatHistoryBodyBytes = 32 << 10

type chatHistoryHandlerFunc func(app *llmapp.AppService, ctx khttp.Context) error

// RegisterChatHistoryRoutes registers user-owned AI chat history REST endpoints.
func RegisterChatHistoryRoutes(s *khttp.Server, app *llmapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/llm/chat/sessions", wrapChatHistory(app, handleListChatSessions))
	r.GET("/api/llm/chat/sessions/{session_id}/messages", wrapChatHistory(app, handleListChatMessages))
	r.POST("/api/llm/chat/sessions", wrapChatHistory(app, handleUpsertChatSession))
	r.DELETE("/api/llm/chat/sessions/{session_id}", wrapChatHistory(app, handleDeleteChatSession))
	r.POST("/api/llm/chat/messages", wrapChatHistory(app, handleUpsertChatMessage))
	r.DELETE("/api/llm/chat/messages/{message_id}", wrapChatHistory(app, handleDeleteChatMessage))
}

func wrapChatHistory(app *llmapp.AppService, h chatHistoryHandlerFunc) func(khttp.Context) error {
	return func(ctx khttp.Context) error { return h(app, ctx) }
}

func writeChatHistoryOK(ctx khttp.Context, data any) error {
	return ctx.Result(http.StatusOK, map[string]any{"code": 0, "msg": "ok", "data": data})
}

func writeChatHistoryErr(ctx khttp.Context, status int, msg string) error {
	return ctx.Result(status, map[string]any{"code": status, "msg": msg})
}

func handleListChatSessions(app *llmapp.AppService, ctx khttp.Context) error {
	limit := intQuery(ctx, "limit")
	items, err := app.ListChatSessions(ctx.Request().Context(), ctx.Request().URL.Query().Get("agent_id"), limit)
	if err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, map[string]any{"items": items})
}

func handleListChatMessages(app *llmapp.AppService, ctx khttp.Context) error {
	sessionID := strings.TrimSpace(ctx.Vars().Get("session_id"))
	items, err := app.ListChatMessages(ctx.Request().Context(), sessionID, intQuery(ctx, "limit"))
	if err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, map[string]any{"items": items})
}

type upsertChatSessionBody struct {
	SessionID string `json:"session_id"`
	AgentID   string `json:"agent_id"`
	Title     string `json:"title"`
	Model     string `json:"model"`
}

func handleUpsertChatSession(app *llmapp.AppService, ctx khttp.Context) error {
	var body upsertChatSessionBody
	if err := decodeChatHistoryBody(ctx, &body); err != nil {
		return writeChatHistoryErr(ctx, http.StatusBadRequest, "请求格式无效")
	}
	item, err := app.UpsertChatSession(ctx.Request().Context(), llmbiz.ChatSessionInput{
		SessionID: body.SessionID,
		AgentID:   body.AgentID,
		Title:     body.Title,
		Model:     body.Model,
	})
	if err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, item)
}

func handleDeleteChatSession(app *llmapp.AppService, ctx khttp.Context) error {
	sessionID := strings.TrimSpace(ctx.Vars().Get("session_id"))
	if err := app.DeleteChatSession(ctx.Request().Context(), sessionID); err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, map[string]bool{"deleted": true})
}

type upsertChatMessageBody struct {
	SessionID   string `json:"session_id"`
	MessageID   string `json:"message_id"`
	SourceMsgID string `json:"source_msg_id"`
	Role        string `json:"role"`
	Content     string `json:"content"`
	Model       string `json:"model"`
	CreatedAtMS int64  `json:"created_at_ms"`
}

func handleUpsertChatMessage(app *llmapp.AppService, ctx khttp.Context) error {
	var body upsertChatMessageBody
	if err := decodeChatHistoryBody(ctx, &body); err != nil {
		return writeChatHistoryErr(ctx, http.StatusBadRequest, "请求格式无效")
	}
	sourceMsgID := strings.TrimSpace(body.SourceMsgID)
	if sourceMsgID == "" {
		sourceMsgID = body.MessageID
	}
	var createdAt time.Time
	if body.CreatedAtMS > 0 {
		createdAt = time.UnixMilli(body.CreatedAtMS)
	}
	item, err := app.UpsertChatMessage(ctx.Request().Context(), llmbiz.ChatMessageInput{
		SessionID:   body.SessionID,
		SourceMsgID: sourceMsgID,
		Role:        body.Role,
		Content:     body.Content,
		Model:       body.Model,
		CreatedAt:   createdAt,
	})
	if err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, item)
}

func handleDeleteChatMessage(app *llmapp.AppService, ctx khttp.Context) error {
	messageID := strings.TrimSpace(ctx.Vars().Get("message_id"))
	if err := app.DeleteChatMessage(ctx.Request().Context(), messageID); err != nil {
		return chatHistoryErr(ctx, err)
	}
	return writeChatHistoryOK(ctx, map[string]bool{"deleted": true})
}

func decodeChatHistoryBody(ctx khttp.Context, dst any) error {
	r := ctx.Request()
	r.Body = http.MaxBytesReader(ctx.Response(), r.Body, maxChatHistoryBodyBytes)
	return json.NewDecoder(r.Body).Decode(dst)
}

func intQuery(ctx khttp.Context, name string) int {
	value := strings.TrimSpace(ctx.Request().URL.Query().Get(name))
	if value == "" {
		return 0
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0
	}
	return parsed
}

func chatHistoryErr(ctx khttp.Context, err error) error {
	switch {
	case errors.Is(err, llmbiz.ErrChatSessionRequired):
		return writeChatHistoryErr(ctx, http.StatusBadRequest, "会话不能为空")
	case errors.Is(err, llmbiz.ErrChatMessageRequired):
		return writeChatHistoryErr(ctx, http.StatusBadRequest, "消息不能为空")
	case errors.Is(err, llmbiz.ErrChatRoleInvalid):
		return writeChatHistoryErr(ctx, http.StatusBadRequest, "消息角色无效")
	default:
		return err
	}
}
