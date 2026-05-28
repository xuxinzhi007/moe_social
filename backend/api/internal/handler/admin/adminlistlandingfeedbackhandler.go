package admin

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminListLandingFeedbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListLandingFeedbackResp{BaseResp: *br})
			return
		}

		var req types.ListLandingFeedbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		page := req.Page
		if page <= 0 {
			page = 1
		}
		pageSize := req.PageSize
		if pageSize <= 0 {
			pageSize = 20
		}

		rpcResp, err := svcCtx.LandingGW.ListLandingFeedback(r.Context(), &moe.ListLandingFeedbackReq{
			Page: int32(page), PageSize: int32(pageSize), Category: strings.TrimSpace(req.Category),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListLandingFeedbackResp{
				BaseResp: common.HandleLandingGWError(err, ""),
			})
			return
		}

		items := make([]types.LandingFeedbackItem, 0, len(rpcResp.Items))
		for _, it := range rpcResp.Items {
			if it == nil {
				continue
			}
			items = append(items, types.LandingFeedbackItem{
				Id: it.Id, Email: it.Email, Category: it.Category, Content: it.Content,
				Source: it.Source, ClientIp: it.ClientIp, UserAgent: it.UserAgent, CreatedAt: it.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ListLandingFeedbackResp{
			BaseResp: common.HandleLandingGWError(nil, "ok"),
			Data:     types.ListLandingFeedbackData{Items: items, Total: int(rpcResp.Total)},
		})
	}
}
