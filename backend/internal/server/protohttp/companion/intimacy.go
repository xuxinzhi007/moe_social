package companionhttp

import (
	"encoding/json"
	"net/http"
	"strings"

	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type intimacyBumpRequest struct {
	Reason string `json:"reason"`
}

const maxIntimacyBumpBodyBytes = 4 << 10

// RegisterIntimacyBumpRoute 注册照料等互动后的亲密度微增端点。
func RegisterIntimacyBumpRoute(s *khttp.Server, app *companionapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.POST("/api/companion/intimacy/bump", func(ctx khttp.Context) error {
		return handleIntimacyBump(ctx, app)
	})
}

func handleIntimacyBump(ctx khttp.Context, app *companionapp.AppService) error {
	w := ctx.Response()
	r := ctx.Request()
	userID, err := actorUserID(r.Context())
	if err != nil {
		return err
	}

	var req intimacyBumpRequest
	r.Body = http.MaxBytesReader(w, r.Body, maxIntimacyBumpBodyBytes)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return kerrors.BadRequest("INVALID_REQUEST", "请求格式无效")
	}
	reason := strings.TrimSpace(strings.ToLower(req.Reason))
	if reason == "" {
		reason = "care"
	}

	profile, err := app.BumpIntimacyByReason(r.Context(), userID, reason)
	if err != nil {
		return err
	}
	return ctx.Result(http.StatusOK, map[string]interface{}{
		"code": 0,
		"msg":  "ok",
		"data": map[string]interface{}{
			"intimacy_score":     profile.IntimacyScore,
			"relationship_level": profile.RelationshipLevel,
		},
	})
}
