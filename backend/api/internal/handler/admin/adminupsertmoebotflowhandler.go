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

func AdminUpsertMoeBotFlowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminUpsertMoeBotFlowReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminUpsertMoeBotFlowReq) (*types.AdminUpsertMoeBotFlowResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			in := moebridge.FlowConfigFromTypes(req)
			saved, err := svcCtx.MoeGW.UpsertBotFlow(r.Context(), agentKey, in)
			if err != nil {
			return &types.AdminUpsertMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
			}
			saved.AgentKey = agentKey
			return &types.AdminUpsertMoeBotFlowResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.FlowDataFromBiz(saved),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
