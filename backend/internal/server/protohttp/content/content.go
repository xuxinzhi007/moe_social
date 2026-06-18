package contenthttp

import (
	"context"
	"encoding/json"
	"errors"

	contentv1 "backend/api/content/v1"
	contentbiz "backend/internal/biz/content"
	contentapp "backend/internal/service/content"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errContentAppNil = status.Error(codes.FailedPrecondition, "ContentApp 未初始化")

// Server 实现 content.v1.ContentService gRPC/HTTP。
type Server struct {
	contentv1.UnimplementedContentServiceServer
	app *contentapp.AppService
}

// New 构造 Content gRPC/HTTP 服务。
func New(app *contentapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*contentapp.AppService, error) {
	if s.app == nil {
		return nil, errContentAppNil
	}
	return s.app, nil
}

func (s *Server) GenerateContent(ctx context.Context, in *contentv1.GenerateContentReq) (*contentv1.GenerateContentResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	opts := map[string]any{}
	if raw := in.GetOptionsJson(); raw != "" {
		_ = json.Unmarshal([]byte(raw), &opts)
	}
	result, err := app.GenerateContent(ctx, contentbiz.GenerateInput{
		UserID:  in.GetUserId(),
		Type:    in.GetType(),
		Prompt:  in.GetPrompt(),
		Options: opts,
	})
	if errors.Is(err, contentbiz.ErrUnsupportedContentType) {
		return nil, status.Error(codes.InvalidArgument, "不支持的内容类型")
	}
	if err != nil {
		return nil, err
	}
	return &contentv1.GenerateContentResp{
		Data: &contentv1.GenerateContentData{
			Id: result.ID, Type: result.Type, Url: result.URL,
			Content: result.Content, CreatedAt: result.CreatedAt,
		},
	}, nil
}
