package logic

import (
	"context"
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostLogic {
	return &GetPostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetPostLogic) GetPost(in *super.GetPostReq) (*super.GetPostResp, error) {
	if in.GetPostId() == "" {
		return nil, errorx.New(400, "帖子ID不能为空")
	}
	post, err := postbiz.GetByID(l.ctx, l.svcCtx.DB, in.GetPostId(), in.GetViewerUserId())
	if err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidPostID):
			return nil, errorx.New(400, "无效的帖子ID")
		case errors.Is(err, postbiz.ErrPostNotFound):
			return nil, errorx.New(404, "帖子不存在")
		default:
			l.Error("查询帖子失败: ", err)
			return nil, errorx.New(500, "服务器内部错误")
		}
	}
	return &super.GetPostResp{Post: post}, nil
}
