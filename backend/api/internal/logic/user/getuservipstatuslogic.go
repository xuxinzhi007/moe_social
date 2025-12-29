package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserVipStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserVipStatusLogic {
	return &GetUserVipStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserVipStatusLogic) GetUserVipStatus(req *types.GetUserActiveVipRecordReq) (resp *types.GetUserVipStatusResp, err error) {
	// 调用RPC服务获取用户VIP状态
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserVipStatus(l.ctx, &super.GetUserVipStatusReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserVipStatusResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.GetUserVipStatusResp{
		BaseResp: common.HandleRPCError(nil, "获取用户VIP状态成功"),
		Data: types.UserVipStatusData{
			IsVip:     rpcResp.IsVip,
			ExpiresAt: rpcResp.ExpiresAt,
			AutoRenew: rpcResp.AutoRenew,
		},
	}, nil
}
