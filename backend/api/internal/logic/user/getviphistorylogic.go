package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipHistoryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetVipHistoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipHistoryLogic {
	return &GetVipHistoryLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetVipHistoryLogic) GetVipHistory(req *types.GetVipHistoryReq) (resp *types.GetVipHistoryResp, err error) {
	// 调用RPC服务获取VIP记录列表
	rpcResp, err := l.svcCtx.SuperRpcClient.GetVipRecords(l.ctx, &rpc.GetVipRecordsReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetVipHistoryResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	// 转换为API响应格式
	respRecords := make([]types.VipRecord, 0, len(rpcResp.Records))
	for _, record := range rpcResp.Records {
		respRecords = append(respRecords, types.VipRecord{
			Id:        record.Id,
			UserId:    record.UserId,
			PlanId:    record.PlanId,
			PlanName:  record.PlanName,
			StartAt:   record.StartAt,
			EndAt:     record.EndAt,
			Status:    record.Status,
			CreatedAt: record.CreatedAt,
		})
	}

	return &types.GetVipHistoryResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP历史记录成功"),
		Data:     respRecords,
		Total:    int(rpcResp.Total),
	}, nil
}
