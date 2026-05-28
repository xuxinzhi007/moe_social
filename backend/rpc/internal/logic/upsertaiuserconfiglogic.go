package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiUserConfigLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiUserConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiUserConfigLogic {
	return &UpsertAiUserConfigLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertAiUserConfigLogic) UpsertAiUserConfig(in *moe.UpsertAiUserConfigReq) (*moe.UpsertAiUserConfigResp, error) {
	return NewAiUserConfigLogic(l.ctx, l.svcCtx).Upsert(in)
}
