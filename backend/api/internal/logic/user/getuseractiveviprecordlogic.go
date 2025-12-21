package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserActiveVipRecordLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserActiveVipRecordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserActiveVipRecordLogic {
	return &GetUserActiveVipRecordLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserActiveVipRecordLogic) GetUserActiveVipRecord(req *types.GetUserActiveVipRecordReq) (resp *types.GetUserActiveVipRecordResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserActiveVipRecord(l.ctx, &rpc.GetUserActiveVipRecordReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserActiveVipRecordResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.GetUserActiveVipRecordResp{
		BaseResp: common.HandleRPCError(nil, "获取用户活跃VIP记录成功"),
		Data: types.VipRecord{
			Id:        rpcResp.Record.Id,
			UserId:    rpcResp.Record.UserId,
			PlanId:    rpcResp.Record.PlanId,
			PlanName:  rpcResp.Record.PlanName,
			StartAt:   rpcResp.Record.StartAt,
			EndAt:     rpcResp.Record.EndAt,
			Status:    rpcResp.Record.Status,
			CreatedAt: rpcResp.Record.CreatedAt,
		},
	}, nil
}
