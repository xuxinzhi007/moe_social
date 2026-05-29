package posthttp

import (
	"context"

	postv1 "backend/api/post/v1"
	postapp "backend/internal/service/post"
)

// Server 实现 post.v1.PostService gRPC（P4-C；与 Super 并存）。
type Server struct {
	postv1.UnimplementedPostServiceServer
	app *postapp.AppService
}

// New 构造 Post gRPC 服务。
func New(app *postapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*postapp.AppService, error) {
	if s.app == nil {
		return nil, errPostAppNil
	}
	return s.app, nil
}

func (s *Server) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetPost(ctx, in)
}

func (s *Server) GetPostHandDraw(ctx context.Context, in *postv1.GetPostHandDrawRequest) (*postv1.GetPostHandDrawReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetPostHandDraw(ctx, in)
}

func (s *Server) GetPosts(ctx context.Context, in *postv1.GetPostsRequest) (*postv1.GetPostsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetPosts(ctx, in)
}

func (s *Server) MoeSearchPosts(ctx context.Context, in *postv1.MoeSearchPostsRequest) (*postv1.MoeSearchPostsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.MoeSearchPosts(ctx, in)
}

func (s *Server) CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreatePost(ctx, in)
}

func (s *Server) LikePost(ctx context.Context, in *postv1.LikePostRequest) (*postv1.LikePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.LikePost(ctx, in)
}

func (s *Server) UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdatePost(ctx, in)
}

func (s *Server) DeletePost(ctx context.Context, in *postv1.DeletePostRequest) (*postv1.DeletePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeletePost(ctx, in)
}

func (s *Server) ReportPost(ctx context.Context, in *postv1.ReportPostRequest) (*postv1.ReportPostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ReportPost(ctx, in)
}
