package post

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ReportPostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ReportPostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.PostGW.ReportPost(r.Context(), &moe.ReportPostReq{
			PostId:         req.PostId,
			ReporterUserId: req.ReporterUserId,
			Reason:         req.Reason,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ReportPostResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ReportPostResp{
			BaseResp: common.HandleRPCError(nil, "举报已提交"),
		})
	}
}
