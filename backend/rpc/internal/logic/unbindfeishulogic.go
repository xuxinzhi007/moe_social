package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UnbindFeishuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUnbindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UnbindFeishuLogic {
	return &UnbindFeishuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UnbindFeishuLogic) UnbindFeishu(in *moe.UnbindFeishuReq) (*moe.UnbindFeishuResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).UnbindFeishu(l.ctx, in)
	return resp, mapUserBizErr(err)
}
