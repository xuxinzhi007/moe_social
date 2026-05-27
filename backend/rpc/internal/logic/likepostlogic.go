package logic

import (
	"context"
	"errors"

	postapp "backend/internal/service/post"
	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"
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
	return &LikePostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *LikePostLogic) LikePost(in *super.LikePostReq) (*super.LikePostResp, error) {
	app := postapp.New(l.svcCtx.DB, l.svcCtx.Config.HandDrawRequireModeration)
	resp, err := app.LikePost(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidPostID):
			return nil, errorx.New(400, "无效的帖子ID")
		case errors.Is(err, postbiz.ErrInvalidUserID):
			return nil, errorx.New(400, "无效的用户ID")
		case errors.Is(err, postbiz.ErrPostNotFound):
			return nil, errorx.New(404, "帖子不存在")
		default:
			l.Error("点赞帖子失败: ", err)
			return nil, errorx.New(500, "点赞失败")
		}
	}
	return resp, nil
}
