package llmhttp

import (
	"context"

	llmv1 "backend/api/llm/v1"
	apicomm "backend/internal/platform/apicomm"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func actorUserID(ctx context.Context) (string, error) {
	if s, err := apicomm.UserIDString(ctx); err == nil {
		return s, nil
	}
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return "", errUnauthorized
	}
	return bearerUserIDString(req)
}

func (s *Server) GetAiUserConfig(ctx context.Context, _ *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetAiUserConfig(ctx, &llmv1.GetAiUserConfigReq{UserId: userID})
}

func (s *Server) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	return app.UpsertAiUserConfig(ctx, in)
}
