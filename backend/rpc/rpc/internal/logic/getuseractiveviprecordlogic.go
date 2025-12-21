package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserActiveVipRecordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserActiveVipRecordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserActiveVipRecordLogic {
	return &GetUserActiveVipRecordLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserActiveVipRecordLogic) GetUserActiveVipRecord(in *rpc.GetUserActiveVipRecordReq) (*rpc.GetUserActiveVipRecordResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetUserActiveVipRecordResp{}, nil
}
