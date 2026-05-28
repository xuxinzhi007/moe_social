package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/brain"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminCurateMoeBrainHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminCurateMoeBrainReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminCurateMoeBrainReq) (*types.AdminCurateMoeBrainResp, error) {
			agentKey := strings.TrimSpace(req.AgentKey)
			results, err := svcCtx.MoeGW.CurateBrain(r.Context(), agentKey, brain.CurateOptions{
			MaxEpisodes:           req.MaxEpisodes,
			MaxAttemptsPerEpisode: req.MaxAttempts,
			MinQuality:            req.MinQuality,
			Force:                 req.Force,
			})
			if err != nil {
			return &types.AdminCurateMoeBrainResp{BaseResp: common.HandleError(err)}, nil
			}
			out := types.AdminCurateMoeBrainData{AgentKey: agentKey, Total: len(results)}
			for _, r := range results {
			if r.Approved {
			out.Approved++
			}
			out.Results = append(out.Results, moebridge.RefineDataFromBiz(r))
			}
			return &types.AdminCurateMoeBrainResp{
			BaseResp: common.HandleError(nil),
			Data:     out,
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
