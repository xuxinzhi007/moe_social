//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateAchievementHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateAchievementReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateAchievementReq) (*types.AdminUpdateAchievementResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpdateAchievement(ctx, &moe.AdminUpdateAchievementReq{
			Id:                req.AchievementId,
			Name:              req.Name,
			Description:       req.Description,
			Enabled:           req.Enabled,
			ExpReward:         int32(req.ExpReward),
			SortOrder:         int32(req.SortOrder),
			UpdateName:        req.UpdateName,
			UpdateDescription: req.UpdateDescription,
			UpdateEnabled:     req.UpdateEnabled,
			UpdateExpReward:   req.UpdateExpReward,
			UpdateSortOrder:   req.UpdateSortOrder,
			})
			if err != nil {
			return &types.AdminUpdateAchievementResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateAchievementResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminAchievementToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "achievement", req.AchievementId, "更新成就定义")
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
