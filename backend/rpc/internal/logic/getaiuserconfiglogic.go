package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetAiUserConfigLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetAiUserConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetAiUserConfigLogic {
	return &GetAiUserConfigLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetAiUserConfigLogic) GetAiUserConfig(in *moe.GetAiUserConfigReq) (*moe.GetAiUserConfigResp, error) {
	return NewAiUserConfigLogic(l.ctx, l.svcCtx).Get(in)
}
