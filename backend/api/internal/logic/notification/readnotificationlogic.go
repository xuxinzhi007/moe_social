package notification

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReadNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewReadNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReadNotificationLogic {
	return &ReadNotificationLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ReadNotificationLogic) ReadNotification(req *types.ReadNotificationReq) (resp *types.BaseResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.ReadNotification(l.ctx, &super.ReadNotificationReq{
		Id:     req.Id,
		UserId: req.UserId,
	})
	if err != nil {
		result := common.HandleRPCError(err, "")
		return &result, nil
	}

	result := common.HandleRPCError(nil, "标记已读成功")
	return &result, nil
}
