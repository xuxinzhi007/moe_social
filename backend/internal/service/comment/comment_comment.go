package commentapp

import (
	commentv1 "backend/api/comment/v1"
	commentbiz "backend/internal/biz/comment"
	"backend/internal/platform/socialhook"
	"backend/pkg/achievement"
	"context"
)

func (s *AppService) GetPostComments(ctx context.Context, in *commentv1.GetPostCommentsRequest) (*commentv1.GetPostCommentsReply, error) {
	items, total, err := commentbiz.ListByPost(ctx, s.store, commentbiz.ListFilter{
		PostID: in.GetPostId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
		ViewerUserID: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &commentv1.GetPostCommentsReply{Comments: items, Total: total}, nil
}

func (s *AppService) CreateComment(ctx context.Context, in *commentv1.CreateCommentRequest) (*commentv1.CreateCommentReply, error) {
	result, err := commentbiz.Create(ctx, s.store, commentbiz.CreateInput{
		PostID: in.GetPostId(), UserID: in.GetUserId(),
		Content: in.GetContent(), ParentID: in.GetParentId(),
	})
	if err != nil {
		return nil, err
	}

	var achUnlocks []achievement.UnlockResult
	if !result.Comment.User.IsBot {
		achUnlocks = socialhook.ApplyCommentCreatedAchievements(s.store.Raw(), result.Comment.UserID)
	}

	return &commentv1.CreateCommentReply{
		Comment: commentbiz.BuildCommentV1(
			result.Comment, result.Comment.User, false, result.ReplyToUserName,
		),
		NewAchievements: achievement.UnlocksToCommentV1(achUnlocks),
	}, nil
}

func (s *AppService) LikeComment(ctx context.Context, in *commentv1.LikeCommentRequest) (*commentv1.LikeCommentReply, error) {
	result, err := commentbiz.Like(ctx, s.store, in.GetCommentId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &commentv1.LikeCommentReply{
		Comment: commentbiz.BuildCommentV1(result.Comment, result.User, result.IsLiked, ""),
	}, nil
}
