package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteCommentLogic {
	return &AdminDeleteCommentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteCommentLogic) AdminDeleteComment(in *super.AdminDeleteCommentReq) (*super.AdminDeleteCommentResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteComment(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
