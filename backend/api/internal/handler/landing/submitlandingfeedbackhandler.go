// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package landing

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/logic/landing"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SubmitLandingFeedbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SubmitLandingFeedbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := landing.NewSubmitLandingFeedbackLogic(r.Context(), svcCtx)
		resp, err := l.SubmitLandingFeedback(
			&req,
			common.ClientIPFromRequest(r),
			r.Header.Get("User-Agent"),
		)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
