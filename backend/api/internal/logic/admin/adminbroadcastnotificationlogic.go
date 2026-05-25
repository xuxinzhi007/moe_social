package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBroadcastNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBroadcastNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBroadcastNotificationLogic {
	return &AdminBroadcastNotificationLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminBroadcastNotificationLogic) AdminBroadcastNotification(req *types.AdminBroadcastNotificationReq) (*types.AdminBroadcastNotificationResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminBroadcastNotification(l.ctx, &super.AdminBroadcastNotificationReq{
		Title:   req.Title,
		Content: req.Content,
	})
	if err != nil {
		return &types.AdminBroadcastNotificationResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	wsSent := chat.NewRemoteWsLogic(l.ctx, l.svcCtx).BroadcastNotification(&chat.BroadcastNotificationReq{
		Type: "system_notification",
		Data: map[string]interface{}{
			"title":   req.Title,
			"content": req.Content,
		},
	})

	resp := &types.AdminBroadcastNotificationResp{
		BaseResp: common.HandleRPCError(nil, "广播成功"),
		Data: types.AdminBroadcastNotificationData{
			NotificationsCreated: int(rpcResp.GetNotificationsCreated()),
			WsSent:               wsSent,
		},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "broadcast", "notification", "", "广播通知")
	}
	return resp, nil
}
