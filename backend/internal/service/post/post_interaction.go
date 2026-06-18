package postapp

import (
	"context"
	"backend/internal/platform/socialhook"
	postv1 "backend/api/post/v1"
	postbiz "backend/internal/biz/post"
)

func (s *AppService) LikePost(ctx context.Context, in *postv1.LikePostRequest) (*postv1.LikePostReply, error) {
	result, err := postbiz.Like(ctx, s.store, in.GetPostId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	if result.DidLike {
		socialhook.ApplyPostLikedAchievements(s.store.Raw(), socialhook.PostLikedMeta{
			PostAuthorUserID: result.Post.UserID,
			PostLikeCount:    result.LikeCount,
		})
	}
	return &postv1.LikePostReply{
		Post: postbiz.BuildPostV1(result.Post, result.User, result.IsLiked),
	}, nil
}

func (s *AppService) ReportPost(ctx context.Context, in *postv1.ReportPostRequest) (*postv1.ReportPostReply, error) {
	if err := postbiz.Report(ctx, s.store, in.GetPostId(), in.GetReporterUserId(), in.GetReason()); err != nil {
		return nil, err
	}
	return &postv1.ReportPostReply{}, nil
}
