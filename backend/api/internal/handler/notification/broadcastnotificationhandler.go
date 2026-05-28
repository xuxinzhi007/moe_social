//go:build hybrid

// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package notification

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func BroadcastNotificationHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.BroadcastNotificationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_ = handlerutil.BroadcastWSNotification(req.Type, req.Data)
		httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{
			Code:    200,
			Message: "广播成功",
			Success: true,
		})
	}
}
