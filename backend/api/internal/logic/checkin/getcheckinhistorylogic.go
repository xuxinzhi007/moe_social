package checkin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetCheckInHistoryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetCheckInHistoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInHistoryLogic {
	return &GetCheckInHistoryLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetCheckInHistoryLogic) GetCheckInHistory(req *types.GetCheckInHistoryReq) (resp *types.GetCheckInHistoryResp, err error) {
	// 调用RPC服务获取签到历史
	rpcResp, err := l.svcCtx.SuperRpcClient.GetCheckInHistory(l.ctx, &super.GetCheckInHistoryReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetCheckInHistoryResp{
			BaseResp: types.BaseResp{
				Code:    -1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	// 转换响应格式
	var records []types.CheckInRecord
	for _, record := range rpcResp.Records {
		records = append(records, types.CheckInRecord{
			CheckInDate:       record.CheckInDate,
			ConsecutiveDays:   int(record.ConsecutiveDays),
			ExpReward:         int(record.ExpReward),
			IsSpecialReward:   record.IsSpecialReward,
			SpecialRewardDesc: record.SpecialRewardDesc,
		})
	}

	return &types.GetCheckInHistoryResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "获取签到历史成功",
			Success: true,
		},
		Data:  records,
		Total: int(rpcResp.Total),
	}, nil
}
