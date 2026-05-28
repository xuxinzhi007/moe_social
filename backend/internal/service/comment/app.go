// Package commentapp 评论域应用服务。
package commentapp

import (
	"context"

	commentv1 "backend/api/comment/v1"
	commentbiz "backend/internal/biz/comment"
	commentdata "backend/internal/data/comment"
	"backend/internal/platform/socialhook"

	"gorm.io/gorm"
)

// AppService 评论应用层。
type AppService struct {
	store commentbiz.CommentStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: commentdata.NewStore(db)}
}

func (s *AppService) GetPostComments(ctx context.Context, in *commentv1.GetPostCommentsRequest) (*commentv1.GetPostCommentsReply, error) {
	items, total, err := commentbiz.ListByPost(ctx, s.store, commentbiz.ListFilter{
		PostID: in.GetPostId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
		ViewerUserID: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &commentv1.GetPostCommentsReply{Comments: commentv1.CommentsFromMoe(items), Total: total}, nil
}

func (s *AppService) CreateComment(ctx context.Context, in *commentv1.CreateCommentRequest) (*commentv1.CreateCommentReply, error) {
	result, err := commentbiz.Create(ctx, s.store, commentbiz.CreateInput{
		PostID: in.GetPostId(), UserID: in.GetUserId(),
		Content: in.GetContent(), ParentID: in.GetParentId(),
	})
	if err != nil {
		return nil, err
	}

	achUnlocks := socialhook.ApplyCommentCreatedAchievements(s.store.Raw(), result.Comment.UserID)

	return &commentv1.CreateCommentReply{
		Comment: commentv1.CommentFromMoe(
			commentbiz.BuildProtoComment(result.Comment, result.Comment.User, false, result.ReplyToUserName),
		),
		NewAchievements: commentv1.AchievementUnlocksFromMoe(achUnlocks),
	}, nil
}

func (s *AppService) LikeComment(ctx context.Context, in *commentv1.LikeCommentRequest) (*commentv1.LikeCommentReply, error) {
	result, err := commentbiz.Like(ctx, s.store, in.GetCommentId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &commentv1.LikeCommentReply{
		Comment: commentv1.CommentFromMoe(
			commentbiz.BuildProtoComment(result.Comment, result.User, result.IsLiked, ""),
		),
	}, nil
}
