package logic

import (
	"context"
	"errors"

	postapp "backend/internal/service/post"
	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreatePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreatePostLogic {
	return &CreatePostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *CreatePostLogic) CreatePost(in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	app := postapp.New(l.svcCtx.DB, l.svcCtx.Config.HandDrawRequireModeration)
	resp, err := app.CreatePost(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, postbiz.ErrEmptyUserID):
			return nil, errorx.New(400, "用户ID不能为空")
		case errors.Is(err, postbiz.ErrInvalidUserID):
			return nil, errorx.New(400, "无效的用户ID")
		case errors.Is(err, postbiz.ErrUserNotFound):
			return nil, errorx.New(404, "用户不存在")
		case errors.Is(err, postbiz.ErrEmptyPostContent):
			return nil, errorx.New(400, "请填写文字、上传图片或添加手绘卡片")
		case errors.Is(err, postbiz.ErrInvalidGroupID):
			return nil, errorx.New(400, "无效的群组ID")
		case errors.Is(err, postbiz.ErrGroupNotFound):
			return nil, errorx.New(404, "群组不存在")
		case errors.Is(err, postbiz.ErrNotGroupMember):
			return nil, errorx.New(403, "加入群组后才能发到本群")
		default:
			l.Error("创建帖子失败: ", err)
			return nil, errorx.New(500, "创建帖子失败")
		}
	}
	return resp, nil
}
