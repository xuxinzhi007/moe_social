//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminRunMoeAgentOnceHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminRunMoeAgentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminRunMoeAgentReq) (*types.AdminRunMoeAgentResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			out, err := svcCtx.MoeGW.RunAgentOnce(ctx, agentKey, req.Async)
			if err != nil {
			return &types.AdminRunMoeAgentResp{BaseResp: common.HandleError(err)}, nil
			}
			data := types.AdminRunMoeAgentData{
			AgentKey:       agentKey,
			Accepted:       out.Accepted,
			AlreadyRunning: out.AlreadyRunning,
			}
			if !out.Accepted && !out.AlreadyRunning {
			data.Ok = out.Result.OK
			data.Detail = out.Result.Detail
			data.PostId = out.Result.PostID
			if data.AgentKey == "" {
			data.AgentKey = out.Result.AgentKey
			}
			}
			return &types.AdminRunMoeAgentResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
