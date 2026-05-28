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

type DeletePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeletePostLogic {
	return &DeletePostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *DeletePostLogic) DeletePost(in *moe.DeletePostReq) (*moe.DeletePostResp, error) {
	if in.GetPostId() == "" || in.GetUserId() == "" {
		return nil, errorx.New(400, "post_id 和 user_id 不能为空")
	}
	app := postapp.New(l.svcCtx.DB, l.svcCtx.Config.HandDrawRequireModeration)
	resp, err := app.DeletePost(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidPostID):
			return nil, errorx.New(400, "无效的 post_id")
		case errors.Is(err, postbiz.ErrInvalidUserID):
			return nil, errorx.New(400, "无效的 user_id")
		case errors.Is(err, postbiz.ErrPostNotFound):
			return nil, errorx.New(404, "帖子不存在")
		case errors.Is(err, postbiz.ErrNotPostOwner):
			return nil, errorx.New(403, "无权删除此帖子")
		default:
			l.Error("删除帖子失败: ", err)
			return nil, errorx.New(500, "删除帖子失败")
		}
	}
	return resp, nil
}
