package logic

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type GetPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostLogic {
	return &GetPostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetPostLogic) GetPost(in *super.GetPostReq) (*super.GetPostResp, error) {
	// 参数验证
	if in.PostId == "" {
		return nil, errorx.New(400, "帖子ID不能为空")
	}
	
	// 转换帖子ID
	postID, err := strconv.ParseUint(in.PostId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的帖子ID")
	}
	
	// 查询帖子，预加载话题标签
	var post model.Post
	err = l.svcCtx.DB.Preload("TopicTags").Where("id = ?", postID).First(&post).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "帖子不存在")
		}
		l.Error("查询帖子失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}
	
	// 查询用户信息
	var user model.User
	err = l.svcCtx.DB.Where("id = ?", post.UserID).First(&user).Error
	if err != nil {
		l.Error("查询用户失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}
	
	// 处理图片数组
	var images []string
	if post.Images != "" {
		json.Unmarshal([]byte(post.Images), &images)
	}
	
	// 获取用户名和头像
	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if user.Username != "" {
		username = user.Username
	} else if user.Email != "" {
		username = user.Email
	}
	if user.Avatar != "" {
		avatar = user.Avatar
	}
	
	// 转换话题标签为响应格式
	topicTags := make([]*super.TopicTag, 0, len(post.TopicTags))
	for _, tag := range post.TopicTags {
		topicTags = append(topicTags, &super.TopicTag{
			Id:    strconv.FormatUint(uint64(tag.ID), 10),
			Name:  tag.Name,
			Color: tag.Color,
		})
	}
	
	// 构建响应
	return &super.GetPostResp{
		Post: &super.Post{
			Id:         in.PostId,
			UserId:     strconv.FormatUint(uint64(post.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    post.Content,
			Images:     images,
			TopicTags:  topicTags,
			Likes:      int32(post.Likes),
			Comments:   int32(post.Comments),
			IsLiked:    false,
			CreatedAt:  post.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
