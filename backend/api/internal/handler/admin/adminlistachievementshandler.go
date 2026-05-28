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

func AdminListAchievementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListAchievementsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListAchievementsReq) (*types.AdminListAchievementsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAchievements(ctx, &moe.AdminListAchievementsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Keyword:  req.Keyword,
			Category: req.Category,
			})
			if err != nil {
			return &types.AdminListAchievementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminAchievementItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminAchievementToTypes(item)
			}
			return &types.AdminListAchievementsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAchievementsData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
