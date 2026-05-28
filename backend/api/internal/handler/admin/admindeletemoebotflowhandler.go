//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminDeleteMoeBotFlowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminDeleteMoeBotFlowReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteMoeBotFlowReq) (*types.AdminDeleteMoeBotFlowResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			cfg, err := svcCtx.MoeGW.DeleteBotFlow(r.Context(), agentKey)
			if err != nil {
			return &types.AdminDeleteMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
			}
			cfg.AgentKey = agentKey
			return &types.AdminDeleteMoeBotFlowResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.FlowDataFromBiz(cfg),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
