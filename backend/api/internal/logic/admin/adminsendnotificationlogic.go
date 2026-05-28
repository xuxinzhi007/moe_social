package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminSendNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminSendNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminSendNotificationLogic {
	return &AdminSendNotificationLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminSendNotificationLogic) AdminSendNotification(req *types.AdminSendNotificationReq) (*types.AdminSendNotificationResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminSendNotification(l.ctx, &moe.AdminSendNotificationReq{
		UserId:  req.UserId,
		Title:   req.Title,
		Content: req.Content,
	})
	if err != nil {
		return &types.AdminSendNotificationResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	wsSent := chat.SendWSNotification(&chat.SendNotificationReq{
		UserID: req.UserId,
		Type:   "system_notification",
		Data: map[string]interface{}{
			"title":   req.Title,
			"content": req.Content,
		},
	})

	resp := &types.AdminSendNotificationResp{
		BaseResp: common.HandleRPCError(nil, "发送成功"),
		Data: types.AdminSendNotificationData{
			NotificationId: rpcResp.GetNotificationId(),
			WsSent:         wsSent,
		},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "send", "notification", req.UserId, "发送用户通知")
	}
	return resp, nil
}
