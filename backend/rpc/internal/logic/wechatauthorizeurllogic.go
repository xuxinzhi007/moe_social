package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type WechatAuthorizeURLLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewWechatAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatAuthorizeURLLogic {
	return &WechatAuthorizeURLLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *WechatAuthorizeURLLogic) WechatAuthorizeURL(in *super.WechatAuthorizeURLReq) (*super.WechatAuthorizeURLResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).WechatAuthorizeURL(l.ctx, in)
	return resp, mapUserBizErr(err)
}
