package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendFeishuTestCardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendFeishuTestCardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendFeishuTestCardLogic {
	return &SendFeishuTestCardLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *SendFeishuTestCardLogic) SendFeishuTestCard(in *super.SendFeishuTestCardReq) (*super.SendFeishuTestCardResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).SendFeishuTestCard(l.ctx, in)
	return resp, mapUserBizErr(err)
}
