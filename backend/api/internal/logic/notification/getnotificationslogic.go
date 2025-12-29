package notification

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetNotificationsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetNotificationsLogic {
	return &GetNotificationsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetNotificationsLogic) GetNotifications(req *types.GetNotificationsReq) (resp *types.GetNotificationsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetNotifications(l.ctx, &super.GetNotificationsReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetNotificationsResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	var notifications []types.Notification
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

	return &types.GetNotificationsResp{
		BaseResp: common.HandleRPCError(nil, "获取通知列表成功"),
		Data:     notifications,
		Total:    int(rpcResp.Total),
	}, nil
}
