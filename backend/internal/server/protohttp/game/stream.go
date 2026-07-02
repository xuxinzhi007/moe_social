package gamehttp

import (
	"encoding/json"
	"io"
	"strconv"
	"strings"

	gameapp "backend/internal/service/game"
	"backend/internal/apilegacy/common"
	gamebiz "backend/internal/biz/game"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type actStreamRequest struct {
	UserID    string `json:"user_id"`
	SessionID uint64 `json:"session_id"`
	Action    string `json:"action"`
}

// RegisterStreamRoute 注册游戏行动 SSE 流式端点（P3）。
func RegisterStreamRoute(s *khttp.Server, app *gameapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.POST("/api/user/{user_id}/game/act/stream", func(ctx khttp.Context) error {
		return handleActStream(ctx, app)
	})
}

func handleActStream(ctx khttp.Context, app *gameapp.AppService) error {
	w := ctx.Response()
	r := ctx.Request()
	common.InitSSEHeaders(w)

	var req actStreamRequest
	body, _ := io.ReadAll(r.Body)
	_ = json.Unmarshal(body, &req)
	if req.UserID == "" {
		req.UserID = ctx.Vars().Get("user_id")
	}
	if req.SessionID == 0 {
		if sid := strings.TrimSpace(r.URL.Query().Get("session_id")); sid != "" {
			if n, err := strconv.ParseUint(sid, 10, 64); err == nil {
				req.SessionID = n
			}
		}
	}
	if strings.TrimSpace(req.Action) == "" {
		_ = common.WriteSSE(w, "error", map[string]string{"message": "action required"})
		return nil
	}

	_ = common.WriteSSE(w, "start", map[string]string{"action": req.Action})

	var streamedProse strings.Builder
	result, err := app.RunActStream(r.Context(), req.UserID, req.SessionID, req.Action, func(chunk string) error {
		streamedProse.WriteString(chunk)
		return common.WriteSSE(w, "delta", map[string]string{"text": chunk})
	})
	if err != nil {
		_ = common.WriteSSE(w, "error", map[string]string{"message": err.Error()})
		return nil
	}

	donePayload := map[string]interface{}{
		"narrative":            toStreamNarrative(result.Narrative),
		"location":             result.Location,
		"game_time":            result.GameTime,
		"overall_favorability": result.OverallFavorability,
		"player_focus":         result.PlayerFocus,
		"narrative_source":     result.NarrativeSource,
		"llm_online":           result.LlmOnline,
		"suggested_actions":    result.SuggestedActions,
		"inventory":            toStreamItems(result.Inventory),
		"npcs":                 toStreamNpcs(result.Npcs),
	}
	_ = common.WriteSSE(w, "done", donePayload)
	return nil
}

func toStreamNarrative(lines []gamebiz.NarrativeLine) []map[string]string {
	out := make([]map[string]string, 0, len(lines))
	for _, line := range lines {
		out = append(out, map[string]string{
			"type":    line.Type,
			"content": line.Content,
			"name":    line.Name,
		})
	}
	return out
}

func toStreamItems(items []gamebiz.ItemView) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		out = append(out, map[string]interface{}{
			"id":           item.ID,
			"name":         item.Name,
			"description":  item.Description,
			"in_inventory": item.InInventory,
		})
	}
	return out
}

func toStreamNpcs(npcs []gamebiz.NpcView) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(npcs))
	for _, npc := range npcs {
		out = append(out, map[string]interface{}{
			"id":           npc.ID,
			"name":         npc.Name,
			"persona":      npc.Persona,
			"favorability": npc.Favorability,
		})
	}
	return out
}
