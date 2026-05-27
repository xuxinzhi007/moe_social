package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFeishuLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuLoginLogic {
	return &FeishuLoginLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *FeishuLoginLogic) FeishuLogin(in *super.FeishuLoginReq) (*super.FeishuLoginResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).FeishuLogin(l.ctx, in)
	return resp, mapUserBizErr(err)
}
