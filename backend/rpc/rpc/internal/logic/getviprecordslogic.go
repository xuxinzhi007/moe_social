package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipRecordsLogic {
	return &GetVipRecordsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// VIP记录相关服务
func (l *GetVipRecordsLogic) GetVipRecords(in *rpc.GetVipRecordsReq) (*rpc.GetVipRecordsResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetVipRecordsResp{}, nil
}
