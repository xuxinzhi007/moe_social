// Package commentapp 评论域应用服务。
package commentapp

import (
	"context"
	"strconv"

	commentbiz "backend/internal/biz/comment"
	"backend/internal/platform/socialhook"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

// AppService 评论应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) GetPostComments(ctx context.Context, in *super.GetPostCommentsReq) (*super.GetPostCommentsResp, error) {
	items, total, err := commentbiz.ListByPost(ctx, s.db, commentbiz.ListFilter{
		PostID: in.GetPostId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
		ViewerUserID: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &super.GetPostCommentsResp{Comments: items, Total: total}, nil
}

func (s *AppService) CreateComment(ctx context.Context, in *super.CreateCommentReq) (*super.CreateCommentResp, error) {
	result, err := commentbiz.Create(ctx, s.db, commentbiz.CreateInput{
		PostID: in.GetPostId(), UserID: in.GetUserId(),
		Content: in.GetContent(), ParentID: in.GetParentId(),
	})
	if err != nil {
		return nil, err
	}

	achUnlocks := socialhook.ApplyCommentCreatedAchievements(s.db, result.Comment.UserID)

	c := result.Comment
	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if c.User.ID > 0 {
		if c.User.Username != "" {
			username = c.User.Username
		} else if c.User.Email != "" {
			username = c.User.Email
		}
		if c.User.Avatar != "" {
			avatar = c.User.Avatar
		}
	}
	return &super.CreateCommentResp{
		Comment: &super.Comment{
			Id: strconv.FormatUint(uint64(c.ID), 10),
			PostId: strconv.FormatUint(uint64(c.PostID), 10),
			UserId: strconv.FormatUint(uint64(c.UserID), 10),
			UserName: username, UserAvatar: avatar, Content: c.Content,
			Likes: int32(c.Likes), IsLiked: false,
			CreatedAt: utils.FormatAPIDateTime(c.CreatedAt),
			ParentId: strconv.FormatUint(uint64(c.ParentID), 10),
			ReplyToUserName: result.ReplyToUserName,
		},
		NewAchievements: achUnlocks,
	}, nil
}

func (s *AppService) LikeComment(ctx context.Context, in *super.LikeCommentReq) (*super.LikeCommentResp, error) {
	result, err := commentbiz.Like(ctx, s.db, in.GetCommentId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &super.LikeCommentResp{
		Comment: commentbiz.BuildProtoComment(result.Comment, result.User, result.IsLiked, ""),
	}, nil
}
