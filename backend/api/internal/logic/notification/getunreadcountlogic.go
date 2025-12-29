package notification

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUnreadCountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUnreadCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUnreadCountLogic {
	return &GetUnreadCountLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUnreadCountLogic) GetUnreadCount(req *types.GetUnreadCountReq) (resp *types.GetUnreadCountResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUnreadCount(l.ctx, &super.GetUnreadCountReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUnreadCountResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.GetUnreadCountResp{
		BaseResp: common.HandleRPCError(nil, "获取未读数成功"),
		Data:     int(rpcResp.Count),
	}, nil
}
