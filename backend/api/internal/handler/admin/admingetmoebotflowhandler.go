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

func AdminGetMoeBotFlowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminGetMoeBotFlowReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetMoeBotFlowReq) (*types.AdminGetMoeBotFlowResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			cfg, err := svcCtx.MoeGW.GetBotFlow(r.Context(), agentKey)
			if err != nil {
			return &types.AdminGetMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
			}
			cfg.AgentKey = agentKey
			return &types.AdminGetMoeBotFlowResp{
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
