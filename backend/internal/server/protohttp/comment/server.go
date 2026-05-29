package commenthttp

import (
	"context"

	commentv1 "backend/api/comment/v1"
	commentapp "backend/internal/service/comment"
)

// Server 实现 comment.v1.CommentService gRPC（P4-C；与 Super 并存）。
type Server struct {
	commentv1.UnimplementedCommentServiceServer
	app *commentapp.AppService
}

// New 构造 Comment gRPC 服务。
func New(app *commentapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*commentapp.AppService, error) {
	if s.app == nil {
		return nil, errCommentAppNil
	}
	return s.app, nil
}

func (s *Server) GetPostComments(ctx context.Context, in *commentv1.GetPostCommentsRequest) (*commentv1.GetPostCommentsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetPostComments(ctx, in)
}

func (s *Server) CreateComment(ctx context.Context, in *commentv1.CreateCommentRequest) (*commentv1.CreateCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateComment(ctx, in)
}

func (s *Server) LikeComment(ctx context.Context, in *commentv1.LikeCommentRequest) (*commentv1.LikeCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.LikeComment(ctx, in)
}
