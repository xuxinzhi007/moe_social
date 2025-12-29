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

type CreatePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreatePostLogic {
	return &CreatePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreatePostLogic) CreatePost(in *super.CreatePostReq) (*super.CreatePostResp, error) {
	// 1. 参数验证
	if in.UserId == "" {
		return nil, errorx.New(400, "用户ID不能为空")
	}
	
	if in.Content == "" {
		return nil, errorx.New(400, "帖子内容不能为空")
	}
	
	// 2. 转换用户ID
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}
	
	// 3. 查找用户，确保用户存在
	var user model.User
	err = l.svcCtx.DB.Where("id = ?", userID).First(&user).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "用户不存在")
		}
		l.Error("查找用户失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}
	
	// 4. 构建帖子数据
	post := model.Post{
		UserID:  uint(userID),
		Content: in.Content,
	}
	
	// 5. 处理图片
	if len(in.Images) > 0 {
		// 将图片数组转换为JSON字符串
		imagesJSON, err := json.Marshal(in.Images)
		if err != nil {
			l.Error("图片数组序列化失败: ", err)
			return nil, errorx.New(500, "服务器内部错误")
		}
		post.Images = string(imagesJSON)
	}
	
	// 6. 保存到数据库
	err = l.svcCtx.DB.Create(&post).Error
	if err != nil {
		l.Error("创建帖子失败: ", err)
		return nil, errorx.New(500, "创建帖子失败")
	}
	
	// 7. 构建响应
	return &super.CreatePostResp{
		Post: &super.Post{
			Id:         strconv.FormatUint(uint64(post.ID), 10),
			UserId:     in.UserId,
			UserName:   user.Username,
			UserAvatar: user.Avatar,
			Content:    post.Content,
			Images:     in.Images,
			Likes:      0,
			Comments:   0,
			IsLiked:    false,
			CreatedAt:  post.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
