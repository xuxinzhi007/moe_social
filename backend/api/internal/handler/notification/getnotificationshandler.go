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

func GetNotificationsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetNotificationsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetNotifications(r.Context(), &moe.GetNotificationsReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetNotificationsResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		notifications := make([]types.Notification, 0, len(rpcResp.Notifications))
		for _, n := range rpcResp.Notifications {
			notifications = append(notifications, types.Notification{
				Id:           n.Id,
				UserId:       n.UserId,
				SenderId:     n.SenderId,
				SenderName:   n.SenderName,
				SenderAvatar: n.SenderAvatar,
				Type:         int(n.Type),
				PostId:       n.PostId,
				Content:      n.Content,
				IsRead:       n.IsRead,
				CreatedAt:    n.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetNotificationsResp{
			BaseResp: common.HandleRPCError(nil, "获取通知列表成功"),
			Data:     notifications,
			Total:    int(rpcResp.Total),
		})
	}
}
