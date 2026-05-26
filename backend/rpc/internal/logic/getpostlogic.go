package logic

import (
	"context"
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

	var viewerUID uint
	if in.ViewerUserId != "" {
		if v, e := strconv.ParseUint(in.ViewerUserId, 10, 32); e == nil {
			viewerUID = uint(v)
		}
	}
	ms := moderationStatusOrDefault(post.ModerationStatus)
	if ms == "rejected" {
		return nil, errorx.New(404, "帖子不存在")
	}
	if ms == "pending" && post.UserID != viewerUID {
		return nil, errorx.New(404, "帖子不存在")
	}
	
	// 查询用户信息
	var user model.User
	err = l.svcCtx.DB.Where("id = ?", post.UserID).First(&user).Error
	if err != nil {
		l.Error("查询用户失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}
	
	isLiked := false
	if viewerUID > 0 {
		liked := LikedTargetIDSet(l.svcCtx.DB, viewerUID, "post", []uint{post.ID})
		isLiked = liked[post.ID]
	}
	rpcPost := buildSuperPost(post, user, isLiked)
	rpcPost.Id = in.PostId
	rpcPost.ModerationStatus = ms

	return &super.GetPostResp{Post: rpcPost}, nil
}
