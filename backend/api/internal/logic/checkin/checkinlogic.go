package checkin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckInLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCheckInLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckInLogic {
	return &CheckInLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CheckInLogic) CheckIn(req *types.CheckInReq) (resp *types.CheckInResp, err error) {
	// 调用RPC服务进行签到
	rpcResp, err := l.svcCtx.SuperRpcClient.CheckIn(l.ctx, &super.CheckInReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.CheckInResp{
			BaseResp: types.BaseResp{
				Code:    -1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	// 转换响应格式
	return &types.CheckInResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "签到成功",
			Success: true,
		},
		Data: types.CheckInData{
			ExpGained:       int(rpcResp.ExpGained),
			NewLevel:        int(rpcResp.NewLevel),
			ConsecutiveDays: int(rpcResp.ConsecutiveDays),
			LevelUp:         rpcResp.LevelUp,
			SpecialReward:   rpcResp.SpecialReward,
		},
	}, nil
}
