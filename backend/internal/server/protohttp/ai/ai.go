package aihttp

import (
	"context"
	"strconv"

	aiv1 "backend/api/ai/v1"
	apicomm "backend/internal/platform/apicomm"
	aiapp "backend/internal/service/ai"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

// Server 实现 ai.v1.AiResources gRPC/HTTP。
type Server struct {
	aiv1.UnimplementedAiResourcesServer
	app *aiapp.AppService
}

// New 构造 AiResources gRPC/HTTP 服务。
func New(app *aiapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*aiapp.AppService, error) {
	if s.app == nil {
		return nil, errAIAppNil
	}
	return s.app, nil
}

func actorUserID(ctx context.Context) (string, error) {
	userID, err := apicomm.UserIDUint(ctx)
	if err != nil || userID == 0 {
		return "", kerrors.Unauthorized("UNAUTHORIZED", "invalid authentication context")
	}
	return strconv.FormatUint(uint64(userID), 10), nil
}

func (s *Server) ListAiProviders(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiProviders(ctx, in)
}

func (s *Server) UpsertAiProvider(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpsertAiProvider(ctx, in)
}

func (s *Server) DeleteAiProvider(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAiProvider(ctx, in)
}

func (s *Server) ListAiAgents(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiAgents(ctx, in)
}

func (s *Server) ListPublicAiAgents(ctx context.Context, in *aiv1.ListPublicAiAgentsReq) (*aiv1.ListAiResourceResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListPublicAiAgents(ctx, in)
}

func (s *Server) UpsertAiAgent(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpsertAiAgent(ctx, in)
}

func (s *Server) DeleteAiAgent(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAiAgent(ctx, in)
}

func (s *Server) ListAiLorebooks(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiLorebooks(ctx, in)
}

func (s *Server) UpsertAiLorebook(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpsertAiLorebook(ctx, in)
}

func (s *Server) DeleteAiLorebook(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAiLorebook(ctx, in)
}
