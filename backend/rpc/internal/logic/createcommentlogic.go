package logic

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/achievement"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

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

	var parentID uint
	if pid := strings.TrimSpace(in.GetParentId()); pid != "" {
		parsed, err := strconv.ParseUint(pid, 10, 32)
		if err != nil || parsed == 0 {
			tx.Rollback()
			return nil, fmt.Errorf("invalid parent_id")
		}
		var parent model.Comment
		if err := tx.First(&parent, parsed).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("parent comment not found")
		}
		if parent.PostID != uint(postID) {
			tx.Rollback()
			return nil, fmt.Errorf("parent comment mismatch")
		}
		parentID = uint(parsed)
	}

	comment := model.Comment{
		PostID:   uint(postID),
		ParentID: parentID,
		UserID:   uint(userID),
		Content:  in.Content,
		Likes:    0,
	}
	if err := tx.Create(&comment).Error; err != nil {
		tx.Rollback()
		l.Error("创建评论失败:", err)
		return nil, err
	}

	if err := tx.Model(&post).Update("comments", post.Comments+1).Error; err != nil {
		l.Error("更新评论数失败:", err)
	}

	notifyContent := in.Content
	if len(notifyContent) > 200 {
		notifyContent = notifyContent[:200]
	}
	if parentID > 0 {
		var parent model.Comment
		if err := tx.First(&parent, parentID).Error; err == nil && parent.UserID != uint(userID) {
			notification := model.Notification{
				UserID:   parent.UserID,
				SenderID: uint(userID),
				Type:     2,
				PostID:   uint(postID),
				Content:  notifyContent,
				IsRead:   false,
			}
			_ = tx.Create(&notification).Error
		}
	} else if uint(userID) != post.UserID {
		notification := model.Notification{
			UserID:   post.UserID,
			SenderID: uint(userID),
			Type:     2,
			PostID:   uint(postID),
			Content:  notifyContent,
			IsRead:   false,
		}
		_ = tx.Create(&notification).Error
	}

	engine := achievement.NewEngine(l.svcCtx.DB)
	achUnlocks, err := engine.ApplyEvent(tx, uint(userID), achievement.Event{Type: achievement.EventCommentCreated})
	if err != nil {
		l.Errorf("成就处理失败（评论仍会发布）: %v", err)
		achUnlocks = nil
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

	replyToName := ""
	if comment.ParentID > 0 {
		var parent model.Comment
		if err := l.svcCtx.DB.Preload("User").First(&parent, comment.ParentID).Error; err == nil {
			if parent.User.Username != "" {
				replyToName = parent.User.Username
			}
		}
	}

	return &super.CreateCommentResp{
		Comment: &super.Comment{
			Id:              strconv.FormatUint(uint64(comment.ID), 10),
			PostId:          strconv.FormatUint(uint64(comment.PostID), 10),
			UserId:          strconv.FormatUint(uint64(comment.UserID), 10),
			UserName:        username,
			UserAvatar:      avatar,
			Content:         comment.Content,
			Likes:           int32(comment.Likes),
			IsLiked:         false,
			CreatedAt:       utils.FormatAPIDateTime(comment.CreatedAt),
			ParentId:        strconv.FormatUint(uint64(comment.ParentID), 10),
			ReplyToUserName: replyToName,
		},
		NewAchievements: achievement.UnlocksToProto(achUnlocks),
	}, nil
}
