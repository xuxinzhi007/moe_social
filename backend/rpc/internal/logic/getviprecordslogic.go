package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipRecordsLogic {
	return &GetVipRecordsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetVipRecordsLogic) GetVipRecords(in *moe.GetVipRecordsReq) (*moe.GetVipRecordsResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).GetVipRecords(l.ctx, in)
	return resp, mapUserBizErr(err)
}
