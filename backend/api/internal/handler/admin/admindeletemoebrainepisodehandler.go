package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteMoeBrainEpisodeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteMoeBrainEpisodeReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteMoeBrainEpisodeReq) (*types.BaseResp, error) {
			if err := svcCtx.MoeGW.DeleteBrainEpisode(ctx, req.Id); err != nil {
			br := common.HandleError(err)
			return &br, nil
			}
			br := common.HandleError(nil)
			return &br, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
