package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ResetPasswordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewResetPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ResetPasswordLogic {
	return &ResetPasswordLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ResetPasswordLogic) ResetPassword(in *moe.ResetPasswordReq) (*moe.ResetPasswordResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).ResetPassword(l.ctx, in)
	return resp, mapUserBizErr(err)
}
