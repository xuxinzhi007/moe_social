package commenthttp

import (
	"context"

	commentv1 "backend/api/comment/v1"
	apicomm "backend/internal/platform/apicomm"
	commentapp "backend/internal/service/comment"
)

// Server 实现 comment.v1.CommentService HTTP/gRPC 适配。
type Server struct {
	commentv1.UnimplementedCommentServiceServer
	app *commentapp.AppService
}

// New 构造 Comment 服务。
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
	if in.GetViewerUserId() == "" {
		in.ViewerUserId = apicomm.ResolveActorUserID(ctx, "")
	}
	out, err := app.GetPostComments(ctx, in)
	if err != nil {
		return nil, mapCommentError(err)
	}
	return out, nil
}

func (s *Server) CreateComment(ctx context.Context, in *commentv1.CreateCommentRequest) (*commentv1.CreateCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	out, err := app.CreateComment(ctx, in)
	if err != nil {
		return nil, mapCommentError(err)
	}
	return out, nil
}

func (s *Server) LikeComment(ctx context.Context, in *commentv1.LikeCommentRequest) (*commentv1.LikeCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	out, err := app.LikeComment(ctx, in)
	if err != nil {
		return nil, mapCommentError(err)
	}
	return out, nil
}
