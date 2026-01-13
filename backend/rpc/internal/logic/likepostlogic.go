package logic

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LikePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLikePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LikePostLogic {
	return &LikePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *LikePostLogic) LikePost(in *super.LikePostReq) (*super.LikePostResp, error) {
	// 解析ID
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

	// 查询帖子是否存在
	var post model.Post
	if err := l.svcCtx.DB.First(&post, postID).Error; err != nil {
		l.Error("查询帖子失败:", err)
		return nil, err
	}

	// 查询用户是否已经点赞
	var postLike model.PostLike
	hasLiked := l.svcCtx.DB.Where("post_id = ? AND user_id = ?", postID, userID).First(&postLike).Error == nil

	// 开启事务
	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	if hasLiked {
		// 取消点赞：软删除PostLike记录
		if err := tx.Delete(&postLike).Error; err != nil {
			tx.Rollback()
			l.Error("取消点赞失败:", err)
			return nil, err
		}
		// 减少点赞数
		if err := tx.Model(&post).Update("likes", post.Likes-1).Error; err != nil {
			tx.Rollback()
			l.Error("更新点赞数失败:", err)
			return nil, err
		}
		post.Likes--
	} else {
		// 添加点赞：创建PostLike记录
		newPostLike := model.PostLike{
			PostID: uint(postID),
			UserID: uint(userID),
		}
		if err := tx.Create(&newPostLike).Error; err != nil {
			tx.Rollback()
			l.Error("添加点赞失败:", err)
			return nil, err
		}
		// 增加点赞数
		if err := tx.Model(&post).Update("likes", post.Likes+1).Error; err != nil {
			tx.Rollback()
			l.Error("更新点赞数失败:", err)
			return nil, err
		}
		post.Likes++
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		l.Error("提交事务失败:", err)
		return nil, err
	}

	// 重新查询帖子（获取最新数据）并加载用户信息
	if err := l.svcCtx.DB.Preload("User").First(&post, postID).Error; err != nil {
		l.Error("重新查询帖子失败:", err)
		return nil, err
	}

	// 处理图片数组
	var images []string
	if post.Images != "" {
		if err := json.Unmarshal([]byte(post.Images), &images); err != nil {
			l.Error("解析图片数组失败:", err)
			images = []string{}
		}
	}

	// 获取用户信息
	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if post.User.ID > 0 {
		if post.User.Username != "" {
			username = post.User.Username
		} else if post.User.Email != "" {
			username = post.User.Email
		}
		if post.User.Avatar != "" {
			avatar = post.User.Avatar
		}
	}

	// 检查当前用户是否点赞（重新查询PostLike）
	var currentLike model.PostLike
	isLiked := l.svcCtx.DB.Where("post_id = ? AND user_id = ?", postID, userID).First(&currentLike).Error == nil

	// 构建响应
	rpcPost := &super.Post{
		Id:         strconv.FormatUint(uint64(post.ID), 10),
		UserId:     strconv.FormatUint(uint64(post.UserID), 10),
		UserName:   username,
		UserAvatar: avatar,
		Content:    post.Content,
		Images:     images,
		Likes:      int32(post.Likes),
		Comments:   int32(post.Comments),
		IsLiked:    isLiked,
		CreatedAt:  post.CreatedAt.Format("2006-01-02 15:04:05"),
	}

	return &super.LikePostResp{
		Post: rpcPost,
	}, nil
}
