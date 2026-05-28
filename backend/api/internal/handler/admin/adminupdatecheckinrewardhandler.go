package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"fmt"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateCheckInRewardHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateCheckInRewardReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateCheckInRewardReq) (*types.AdminUpdateCheckInRewardResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpdateCheckInReward(ctx, &moe.AdminUpdateCheckInRewardReq{
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
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "check_in_reward", fmt.Sprintf("%d", req.RewardId), "更新签到奖励")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
