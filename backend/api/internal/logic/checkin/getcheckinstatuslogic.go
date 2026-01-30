package checkin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetCheckInStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetCheckInStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInStatusLogic {
	return &GetCheckInStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetCheckInStatusLogic) GetCheckInStatus(req *types.GetCheckInStatusReq) (resp *types.GetCheckInStatusResp, err error) {
	// 调用RPC服务获取签到状态
	rpcResp, err := l.svcCtx.SuperRpcClient.GetCheckInStatus(l.ctx, &super.GetCheckInStatusReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetCheckInStatusResp{
			BaseResp: types.BaseResp{
				Code:    -1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	// 转换响应格式
	return &types.GetCheckInStatusResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "获取签到状态成功",
			Success: true,
		},
		Data: types.CheckInStatus{
			HasCheckedToday: rpcResp.Status.HasCheckedToday,
			ConsecutiveDays: int(rpcResp.Status.ConsecutiveDays),
			TodayReward:     int(rpcResp.Status.TodayReward),
			NextDayReward:   int(rpcResp.Status.NextDayReward),
			CanCheckIn:      rpcResp.Status.CanCheckIn,
		},
	}, nil
}
