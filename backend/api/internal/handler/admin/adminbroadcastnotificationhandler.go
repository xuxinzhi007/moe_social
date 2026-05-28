package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminBroadcastNotificationHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminBroadcastNotificationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminBroadcastNotificationReq) (*types.AdminBroadcastNotificationResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminBroadcastNotification(ctx, &moe.AdminBroadcastNotificationReq{
			Title:   req.Title,
			Content: req.Content,
			})
			if err != nil {
			return &types.AdminBroadcastNotificationResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			wsSent := handlerutil.BroadcastWSNotification("system_notification", map[string]interface{}{
				"title":   req.Title,
				"content": req.Content,
			})

			resp := &types.AdminBroadcastNotificationResp{
			BaseResp: common.HandleRPCError(nil, "广播成功"),
			Data: types.AdminBroadcastNotificationData{
			NotificationsCreated: int(rpcResp.GetNotificationsCreated()),
			WsSent:               wsSent,
			},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "broadcast", "notification", "", "广播通知")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
