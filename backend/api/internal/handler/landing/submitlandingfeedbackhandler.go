package landing

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SubmitLandingFeedbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SubmitLandingFeedbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		source := strings.TrimSpace(req.Source)
		if source == "" {
			source = "official-site"
		}

		_, err := svcCtx.LandingGW.SubmitLandingFeedback(r.Context(), &moe.SubmitLandingFeedbackReq{
			Email: strings.TrimSpace(req.Email), Category: strings.TrimSpace(req.Category),
			Content: req.Content, Source: source,
			ClientIp: common.ClientIPFromRequest(r), UserAgent: r.Header.Get("User-Agent"),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SubmitLandingFeedbackResp{
				BaseResp: common.HandleLandingGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.SubmitLandingFeedbackResp{
			BaseResp: common.HandleLandingGWError(nil, "感谢你的反馈，我们已收到"),
		})
	}
}
