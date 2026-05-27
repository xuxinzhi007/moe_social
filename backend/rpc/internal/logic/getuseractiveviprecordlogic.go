package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserActiveVipRecordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserActiveVipRecordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserActiveVipRecordLogic {
	return &GetUserActiveVipRecordLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserActiveVipRecordLogic) GetUserActiveVipRecord(in *super.GetUserActiveVipRecordReq) (*super.GetUserActiveVipRecordResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).GetUserActiveVipRecord(l.ctx, in)
	return resp, mapUserBizErr(err)
}
