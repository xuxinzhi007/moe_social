package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/achievement"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateCommentLogic {
	return &CreateCommentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateCommentLogic) CreateComment(in *super.CreateCommentReq) (*super.CreateCommentResp, error) {
	postID, err := strconv.ParseUint(in.PostId, 10, 32)
	if err != nil {
		l.Error("解析帖子ID失败:", err)
		return nil, err
	}

	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		l.Error("解析用户ID失败:", err)
		return nil, err
	}

	var post model.Post
	if err := l.svcCtx.DB.First(&post, postID).Error; err != nil {
		l.Error("查询帖子失败:", err)
		return nil, err
	}

	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		l.Error("查询用户失败:", err)
		return nil, err
	}

	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	comment := model.Comment{
		PostID:  uint(postID),
		UserID:  uint(userID),
		Content: in.Content,
		Likes:   0,
	}
	if err := tx.Create(&comment).Error; err != nil {
		tx.Rollback()
		l.Error("创建评论失败:", err)
		return nil, err
	}

	if err := tx.Model(&post).Update("comments", post.Comments+1).Error; err != nil {
		l.Error("更新评论数失败:", err)
	}

	if uint(userID) != post.UserID {
		notification := model.Notification{
			UserID:   post.UserID,
			SenderID: uint(userID),
			Type:     2,
			PostID:   uint(postID),
			Content:  in.Content,
			IsRead:   false,
		}
		_ = tx.Create(&notification).Error
	}

	engine := achievement.NewEngine(l.svcCtx.DB)
	achUnlocks, err := engine.ApplyEvent(tx, uint(userID), achievement.Event{Type: achievement.EventCommentCreated})
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	if err := l.svcCtx.DB.Preload("User").First(&comment, comment.ID).Error; err != nil {
		l.Error("重新查询评论失败:", err)
		return nil, err
	}

	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if comment.User.ID > 0 {
		if comment.User.Username != "" {
			username = comment.User.Username
		} else if comment.User.Email != "" {
			username = comment.User.Email
		}
		if comment.User.Avatar != "" {
			avatar = comment.User.Avatar
		}
	}

	return &super.CreateCommentResp{
		Comment: &super.Comment{
			Id:         strconv.FormatUint(uint64(comment.ID), 10),
			PostId:     strconv.FormatUint(uint64(comment.PostID), 10),
			UserId:     strconv.FormatUint(uint64(comment.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    comment.Content,
			Likes:      int32(comment.Likes),
			IsLiked:    false,
			CreatedAt:  comment.CreatedAt.Format("2006-01-02 15:04:05"),
		},
		NewAchievements: achievement.UnlocksToProto(achUnlocks),
	}, nil
}
