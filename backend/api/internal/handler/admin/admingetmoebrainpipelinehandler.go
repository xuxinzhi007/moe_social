package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetMoeBrainPipelineHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminGetMoeBrainPipelineReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetMoeBrainPipelineReq) (*types.AdminGetMoeBrainPipelineResp, error) {
			snap, err := svcCtx.MoeGW.GetBrainPipeline(r.Context(), req.AgentKey)
			if err != nil {
			return &types.AdminGetMoeBrainPipelineResp{BaseResp: common.HandleError(err)}, nil
			}
			return &types.AdminGetMoeBrainPipelineResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.PipelineDataFromBiz(snap),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
