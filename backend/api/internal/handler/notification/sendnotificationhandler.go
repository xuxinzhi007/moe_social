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

func SendNotificationHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendNotificationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		success := handlerutil.SendWSNotification(req.UserId, req.Type, req.Data)
		if !success {
			httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{
				Code:    500,
				Message: "发送失败",
				Success: false,
			})
			return
		}
		httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{
			Code:    200,
			Message: "发送成功",
			Success: true,
		})
	}
}
