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

func AdminGetMoeBrainHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetMoeBrainReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminGetMoeBrainReq) (*types.AdminGetMoeBrainResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			snap, err := svcCtx.MoeGW.GetBrainSnapshot(ctx, agentKey)
			if err != nil {
			return &types.AdminGetMoeBrainResp{BaseResp: common.HandleError(err)}, nil
			}
			return &types.AdminGetMoeBrainResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.BrainDataFromSnapshot(snap),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
