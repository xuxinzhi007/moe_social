//go:build hybrid

package notification

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ReadNotificationHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ReadNotificationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.UserGW.ReadNotification(r.Context(), &moe.ReadNotificationReq{
			Id:     req.Id,
			UserId: req.UserId,
		})
		if err != nil {
			result := common.HandleRPCError(err, "")
			httpx.OkJsonCtx(r.Context(), w, &result)
			return
		}

		result := common.HandleRPCError(nil, "标记已读成功")
		httpx.OkJsonCtx(r.Context(), w, &result)
	}
}
