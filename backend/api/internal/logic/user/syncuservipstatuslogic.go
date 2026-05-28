package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SyncUserVipStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSyncUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SyncUserVipStatusLogic {
	return &SyncUserVipStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SyncUserVipStatusLogic) SyncUserVipStatus(req *types.SyncUserVipStatusReq) (resp *types.SyncUserVipStatusResp, err error) {
	// 调用RPC服务同步用户VIP状态
	rpcResp, err := l.svcCtx.UserGW.SyncUserVipStatus(l.ctx, &moe.SyncUserVipStatusReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.SyncUserVipStatusResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.SyncUserVipStatusResp{
		BaseResp: common.HandleRPCError(nil, "同步用户VIP状态成功"),
		Data: types.SyncUserVipStatusData{
			IsVip:     rpcResp.IsVip,
			ExpiresAt: rpcResp.ExpiresAt,
		},
	}, nil
}
