package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserInfoLogic {
	return &UpdateUserInfoLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpdateUserInfoLogic) UpdateUserInfo(in *super.UpdateUserInfoReq) (*super.UpdateUserInfoResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).UpdateUserInfo(l.ctx, in)
	return resp, mapUserBizErr(err)
}
