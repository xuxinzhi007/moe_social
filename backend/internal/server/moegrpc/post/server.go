package postgrpc

import (
	"context"

	postv1 "backend/api/post/v1"
	postapp "backend/internal/service/post"
	moerpc "backend/rpc/pb/moe"
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
	resp, err := app.GetPost(ctx, &moerpc.GetPostReq{
		PostId: in.GetPostId(), ViewerUserId: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostReply{Post: postToProto(resp.GetPost())}, nil
}

func (s *Server) MoeSearchPosts(ctx context.Context, in *postv1.MoeSearchPostsRequest) (*postv1.MoeSearchPostsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.MoeSearchPosts(ctx, &moerpc.MoeSearchPostsReq{
		Query: in.GetQuery(), Limit: in.GetLimit(), ViewerUserId: in.GetViewerUserId(),
		MoodTag: in.GetMoodTag(), TopicTagId: in.GetTopicTagId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.MoeSearchPostsReply{
		Items: searchHitsToProto(resp.GetItems()), Total: resp.GetTotal(),
	}, nil
}

func (s *Server) CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.CreatePost(ctx, &moerpc.CreatePostReq{
		UserId: in.GetUserId(), Content: in.GetContent(), Images: in.GetImages(),
		TopicTags: topicTagsFromProto(in.GetTopicTags()), HandDrawCard: in.GetHandDrawCard(),
		HandDrawThumbUrl: in.GetHandDrawThumbUrl(), MoodTag: in.GetMoodTag(), GroupId: in.GetGroupId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.CreatePostReply{
		Post:            postToProto(resp.GetPost()),
		NewAchievements: achievementUnlocksToProto(resp.GetNewAchievements()),
	}, nil
}

func (s *Server) LikePost(ctx context.Context, in *postv1.LikePostRequest) (*postv1.LikePostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.LikePost(ctx, &moerpc.LikePostReq{
		PostId: in.GetPostId(), UserId: in.GetUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.LikePostReply{Post: postToProto(resp.GetPost())}, nil
}
