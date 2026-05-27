package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type WechatLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewWechatLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatLoginLogic {
	return &WechatLoginLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *WechatLoginLogic) WechatLogin(in *super.WechatLoginReq) (*super.WechatLoginResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).WechatLogin(l.ctx, in)
	return resp, mapUserBizErr(err)
}
