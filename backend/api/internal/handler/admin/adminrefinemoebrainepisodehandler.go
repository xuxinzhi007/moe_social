//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/brain"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminRefineMoeBrainEpisodeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminRefineMoeBrainEpisodeReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminRefineMoeBrainEpisodeReq) (*types.AdminRefineMoeBrainEpisodeResp, error) {
			res, err := svcCtx.MoeGW.RefineBrainEpisode(r.Context(), req.Id, brain.RefineOptions{MaxAttempts: req.MaxAttempts})
			if err != nil && !res.OK {
			return &types.AdminRefineMoeBrainEpisodeResp{BaseResp: common.HandleError(err)}, nil
			}
			return &types.AdminRefineMoeBrainEpisodeResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.RefineDataFromBiz(res),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
