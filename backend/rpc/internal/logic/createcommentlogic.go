package logic

import (
	"context"
	"strconv"

	"backend/model"
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

// 评论相关服务
func (l *CreateCommentLogic) CreateComment(in *super.CreateCommentReq) (*super.CreateCommentResp, error) {
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

	// 验证帖子是否存在
	var post model.Post
	if err := l.svcCtx.DB.First(&post, postID).Error; err != nil {
		l.Error("查询帖子失败:", err)
		return nil, err
	}

	// 验证用户是否存在
	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		l.Error("查询用户失败:", err)
		return nil, err
	}

	// 创建评论
	comment := model.Comment{
		PostID:  uint(postID),
		UserID:  uint(userID),
		Content: in.Content,
		Likes:   0,
	}

	if err := l.svcCtx.DB.Create(&comment).Error; err != nil {
		l.Error("创建评论失败:", err)
		return nil, err
	}

	// 更新帖子的评论数
	if err := l.svcCtx.DB.Model(&post).Update("comments", post.Comments+1).Error; err != nil {
		l.Error("更新评论数失败:", err)
		// 不返回错误，因为评论已经创建成功
	}

	// 创建通知 (如果不是自己评论自己)
	if uint(userID) != post.UserID {
		notification := model.Notification{
			UserID:   post.UserID,
			SenderID: uint(userID),
			Type:     2, // 2:评论
			PostID:   uint(postID),
			Content:  in.Content,
			IsRead:   false,
		}
		if err := l.svcCtx.DB.Create(&notification).Error; err != nil {
			l.Error("创建通知失败:", err)
		}
	}

	// 重新查询评论（获取最新数据）并加载用户信息
	if err := l.svcCtx.DB.Preload("User").First(&comment, comment.ID).Error; err != nil {
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

	// 构建响应
	rpcComment := &super.Comment{
		Id:         strconv.FormatUint(uint64(comment.ID), 10),
		PostId:     strconv.FormatUint(uint64(comment.PostID), 10),
		UserId:     strconv.FormatUint(uint64(comment.UserID), 10),
		UserName:   username,
		UserAvatar: avatar,
		Content:    comment.Content,
		Likes:      int32(comment.Likes),
		IsLiked:    false,
		CreatedAt:  comment.CreatedAt.Format("2006-01-02 15:04:05"),
	}

	return &super.CreateCommentResp{
		Comment: rpcComment,
	}, nil
}
