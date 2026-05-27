package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type BindFeishuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewBindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *BindFeishuLogic {
	return &BindFeishuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *BindFeishuLogic) BindFeishu(in *super.BindFeishuReq) (*super.BindFeishuResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).BindFeishu(l.ctx, in)
	return resp, mapUserBizErr(err)
}
