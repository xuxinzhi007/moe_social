package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LikeCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLikeCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LikeCommentLogic {
	return &LikeCommentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *LikeCommentLogic) LikeComment(in *super.LikeCommentReq) (*super.LikeCommentResp, error) {
	// 解析ID
	commentID, err := strconv.ParseUint(in.CommentId, 10, 32)
	if err != nil {
		l.Error("解析评论ID失败:", err)
		return nil, err
	}

	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		l.Error("解析用户ID失败:", err)
		return nil, err
	}

	// 查询评论是否存在
	var comment model.Comment
	if err := l.svcCtx.DB.First(&comment, commentID).Error; err != nil {
		l.Error("查询评论失败:", err)
		return nil, err
	}

	// 查询用户是否已经点赞
	var commentLike model.CommentLike
	hasLiked := l.svcCtx.DB.Where("comment_id = ? AND user_id = ?", commentID, userID).First(&commentLike).Error == nil

	// 开启事务
	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	if hasLiked {
		// 取消点赞：软删除CommentLike记录
		if err := tx.Delete(&commentLike).Error; err != nil {
			tx.Rollback()
			l.Error("取消点赞失败:", err)
			return nil, err
		}
		// 减少点赞数
		if err := tx.Model(&comment).Update("likes", comment.Likes-1).Error; err != nil {
			tx.Rollback()
			l.Error("更新点赞数失败:", err)
			return nil, err
		}
		comment.Likes--
	} else {
		// 添加点赞：创建CommentLike记录
		newCommentLike := model.CommentLike{
			CommentID: uint(commentID),
			UserID:    uint(userID),
		}
		if err := tx.Create(&newCommentLike).Error; err != nil {
			tx.Rollback()
			l.Error("添加点赞失败:", err)
			return nil, err
		}
		// 增加点赞数
		if err := tx.Model(&comment).Update("likes", comment.Likes+1).Error; err != nil {
			tx.Rollback()
			l.Error("更新点赞数失败:", err)
			return nil, err
		}
		comment.Likes++
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		l.Error("提交事务失败:", err)
		return nil, err
	}

	// 重新查询评论（获取最新数据）并加载用户信息
	if err := l.svcCtx.DB.Preload("User").First(&comment, commentID).Error; err != nil {
		l.Error("重新查询评论失败:", err)
		return nil, err
	}

	// 获取用户信息
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

	// 检查当前用户是否点赞（重新查询CommentLike）
	var currentLike model.CommentLike
	isLiked := l.svcCtx.DB.Where("comment_id = ? AND user_id = ?", commentID, userID).First(&currentLike).Error == nil

	// 构建响应
	rpcComment := &super.Comment{
		Id:         strconv.FormatUint(uint64(comment.ID), 10),
		PostId:     strconv.FormatUint(uint64(comment.PostID), 10),
		UserId:     strconv.FormatUint(uint64(comment.UserID), 10),
		UserName:   username,
		UserAvatar: avatar,
		Content:    comment.Content,
		Likes:      int32(comment.Likes),
		IsLiked:    isLiked,
		CreatedAt:  comment.CreatedAt.Format("2006-01-02 15:04:05"),
	}

	return &super.LikeCommentResp{
		Comment: rpcComment,
	}, nil
}
