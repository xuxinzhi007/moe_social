package commentgrpc

import (
	"context"

	commentv1 "backend/api/comment/v1"
	commentapp "backend/internal/service/comment"
	moerpc "backend/rpc/pb/moe"
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
	resp, err := app.GetPostComments(ctx, &moerpc.GetPostCommentsReq{
		PostId: in.GetPostId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
		ViewerUserId: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &commentv1.GetPostCommentsReply{
		Comments: commentsToProto(resp.GetComments()), Total: resp.GetTotal(),
	}, nil
}

func (s *Server) CreateComment(ctx context.Context, in *commentv1.CreateCommentRequest) (*commentv1.CreateCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.CreateComment(ctx, &moerpc.CreateCommentReq{
		PostId: in.GetPostId(), UserId: in.GetUserId(),
		Content: in.GetContent(), ParentId: in.GetParentId(),
	})
	if err != nil {
		return nil, err
	}
	return &commentv1.CreateCommentReply{
		Comment: commentToProto(resp.GetComment()),
		NewAchievements: achievementUnlocksToProto(resp.GetNewAchievements()),
	}, nil
}

func (s *Server) LikeComment(ctx context.Context, in *commentv1.LikeCommentRequest) (*commentv1.LikeCommentReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.LikeComment(ctx, &moerpc.LikeCommentReq{
		CommentId: in.GetCommentId(), UserId: in.GetUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &commentv1.LikeCommentReply{Comment: commentToProto(resp.GetComment())}, nil
}
