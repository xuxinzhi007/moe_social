package admin

import (
	"context"
	"fmt"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateCheckInRewardLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateCheckInRewardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateCheckInRewardLogic {
	return &AdminUpdateCheckInRewardLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateCheckInRewardLogic) AdminUpdateCheckInReward(req *types.AdminUpdateCheckInRewardReq) (*types.AdminUpdateCheckInRewardResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateCheckInReward(l.ctx, &super.AdminUpdateCheckInRewardReq{
		Id:                    req.RewardId,
		ConsecutiveDays:       int32(req.ConsecutiveDays),
		ExpReward:             int32(req.ExpReward),
		ExtraReward:           req.ExtraReward,
		UpdateConsecutiveDays: req.UpdateConsecutiveDays,
		UpdateExpReward:       req.UpdateExpReward,
		UpdateExtraReward:     req.UpdateExtraReward,
	})
	if err != nil {
		return &types.AdminUpdateCheckInRewardResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	resp := &types.AdminUpdateCheckInRewardResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminCheckInRewardToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "check_in_reward", fmt.Sprintf("%d", req.RewardId), "更新签到奖励")
	}
	return resp, nil
}
