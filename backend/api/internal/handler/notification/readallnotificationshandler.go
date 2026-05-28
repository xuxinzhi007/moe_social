package notification

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ReadAllNotificationsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ReadAllNotificationsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.UserGW.ReadAllNotifications(r.Context(), &moe.ReadAllNotificationsReq{
			UserId: req.UserId,
		})
		if err != nil {
			result := common.HandleRPCError(err, "")
			httpx.OkJsonCtx(r.Context(), w, &result)
			return
		}

		result := common.HandleRPCError(nil, "标记全部已读成功")
		httpx.OkJsonCtx(r.Context(), w, &result)
	}
}
