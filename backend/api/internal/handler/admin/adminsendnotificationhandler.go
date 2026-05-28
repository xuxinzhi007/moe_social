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

func AdminSendNotificationHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminSendNotificationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminSendNotificationReq) (*types.AdminSendNotificationResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminSendNotification(ctx, &moe.AdminSendNotificationReq{
			UserId:  req.UserId,
			Title:   req.Title,
			Content: req.Content,
			})
			if err != nil {
			return &types.AdminSendNotificationResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			wsSent := handlerutil.SendWSNotification(req.UserId, "system_notification", map[string]interface{}{
				"title":   req.Title,
				"content": req.Content,
			})

			resp := &types.AdminSendNotificationResp{
			BaseResp: common.HandleRPCError(nil, "发送成功"),
			Data: types.AdminSendNotificationData{
			NotificationId: rpcResp.GetNotificationId(),
			WsSent:         wsSent,
			},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "send", "notification", req.UserId, "发送用户通知")
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
