//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	moeadmin "backend/internal/service/moe"
	moebiz "backend/internal/biz/moe"
)

func AdminGetMoeToolStatsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetMoeToolStatsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminGetMoeToolStatsReq) (*types.AdminGetMoeToolStatsResp, error) {
			stats, err := svcCtx.MoeGW.QueryToolStats(ctx, moebiz.ToolStatsFilter{
			From:     moeadmin.ParseTimeFilter(req.From, false),
			To:       moeadmin.ParseTimeFilter(req.To, true),
			AgentKey: req.AgentKey,
			Tool:     req.Tool,
			})
			if err != nil {
			return &types.AdminGetMoeToolStatsResp{BaseResp: common.HandleError(err)}, nil
			}
			return &types.AdminGetMoeToolStatsResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.ToolStatsDataFromBiz(stats),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
