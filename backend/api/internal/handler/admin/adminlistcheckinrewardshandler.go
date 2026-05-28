package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListCheckInRewardsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (*types.AdminListCheckInRewardsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListCheckInRewards(ctx, &moe.AdminListCheckInRewardsReq{})
			if err != nil {
			return &types.AdminListCheckInRewardsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminCheckInRewardItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminCheckInRewardToTypes(item)
			}
			return &types.AdminListCheckInRewardsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
