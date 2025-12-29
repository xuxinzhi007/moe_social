package notification

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReadAllNotificationsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewReadAllNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReadAllNotificationsLogic {
	return &ReadAllNotificationsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ReadAllNotificationsLogic) ReadAllNotifications(req *types.ReadAllNotificationsReq) (resp *types.BaseResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.ReadAllNotifications(l.ctx, &super.ReadAllNotificationsReq{
		UserId: req.UserId,
	})
	if err != nil {
		result := common.HandleRPCError(err, "")
		return &result, nil
	}

	result := common.HandleRPCError(nil, "标记全部已读成功")
	return &result, nil
}
