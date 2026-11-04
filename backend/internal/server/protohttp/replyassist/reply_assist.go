package replyassisthttp

import (
	"context"
	"errors"

	replyassistv1 "backend/api/replyassist/v1"
	apicomm "backend/internal/platform/apicomm"
	replyassistapp "backend/internal/service/replyassist"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

var errReplyAssistAppNil = errors.New("reply assist service unavailable")

// Server implements replyassist.v1.ReplyAssist HTTP/gRPC bindings.
type Server struct {
	replyassistv1.UnimplementedReplyAssistServer
	app *replyassistapp.AppService
}

// New constructs the HTTP adapter.
func New(app *replyassistapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*replyassistapp.AppService, error) {
	if s.app == nil {
		return nil, errReplyAssistAppNil
	}
	return s.app, nil
}

func actorUserID(ctx context.Context) (uint, error) {
	userID, err := apicomm.UserIDUint(ctx)
	if err != nil || userID == 0 {
		return 0, kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
	}
	return userID, nil
}

// Suggest handles POST /api/reply-assist/suggest.
func (s *Server) Suggest(ctx context.Context, in *replyassistv1.ReplyAssistSuggestRequest) (*replyassistv1.ReplyAssistSuggestReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.Suggest(ctx, userID, in)
}
