package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *UpsertAiUserConfigLogic) UpsertAiUserConfig(in *super.UpsertAiUserConfigReq) (*super.UpsertAiUserConfigResp, error) {
	// todo: add your logic here and delete this line

	return &super.UpsertAiUserConfigResp{}, nil
}
