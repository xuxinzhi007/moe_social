package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserVipLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserVipLogic {
	return &UpdateUserVipLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpdateUserVipLogic) UpdateUserVip(in *super.UpdateUserVipReq) (*super.UpdateUserVipResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).UpdateUserVip(l.ctx, in)
	return resp, mapUserBizErr(err)
}
