package postapp

import (
	"context"
	postv1 "backend/api/post/v1"
	postbiz "backend/internal/biz/post"
)

func (s *AppService) MoeSearchPosts(ctx context.Context, in *postv1.MoeSearchPostsRequest) (*postv1.MoeSearchPostsReply, error) {
	return postbiz.Search(ctx, s.store, postbiz.SearchInput{
		Query: in.GetQuery(), Limit: in.GetLimit(),
		ViewerUserID: in.GetViewerUserId(), MoodTag: in.GetMoodTag(), TopicTagID: in.GetTopicTagId(),
	})
}

func (s *AppService) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	post, err := postbiz.GetByID(ctx, s.store, in.GetPostId(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostReply{Post: post}, nil
}

func (s *AppService) GetPostHandDraw(ctx context.Context, in *postv1.GetPostHandDrawRequest) (*postv1.GetPostHandDrawReply, error) {
	return postbiz.GetHandDraw(ctx, s.store, in.GetPostId(), in.GetViewerUserId())
}

func (s *AppService) GetPosts(ctx context.Context, in *postv1.GetPostsRequest) (*postv1.GetPostsReply, error) {
	posts, total, err := postbiz.List(ctx, s.store, postbiz.ListFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserID: in.GetViewerUserId(),
		FeedMode: in.GetFeedMode(), TopicTagID: in.GetTopicTagId(), AuthorUserID: in.GetAuthorUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostsReply{Posts: posts, Total: total}, nil
}
