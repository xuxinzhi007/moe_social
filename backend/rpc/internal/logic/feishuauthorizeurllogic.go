package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuAuthorizeURLLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFeishuAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuAuthorizeURLLogic {
	return &FeishuAuthorizeURLLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *FeishuAuthorizeURLLogic) FeishuAuthorizeURL(in *moe.FeishuAuthorizeURLReq) (*moe.FeishuAuthorizeURLResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).FeishuAuthorizeURL(l.ctx, in)
	return resp, mapUserBizErr(err)
}
