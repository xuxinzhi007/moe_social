package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserPasswordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserPasswordLogic {
	return &UpdateUserPasswordLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpdateUserPasswordLogic) UpdateUserPassword(in *super.UpdateUserPasswordReq) (*super.UpdateUserPasswordResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).UpdateUserPassword(l.ctx, in)
	return resp, mapUserBizErr(err)
}
