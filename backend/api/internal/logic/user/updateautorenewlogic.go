package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateAutoRenewLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateAutoRenewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateAutoRenewLogic {
	return &UpdateAutoRenewLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateAutoRenewLogic) UpdateAutoRenew(req *types.UpdateAutoRenewReq) (resp *types.EmptyResp, err error) {
	// 调用RPC服务更新自动续费状态
	_, err = l.svcCtx.SuperRpcClient.UpdateAutoRenew(l.ctx, &super.UpdateAutoRenewReq{
		UserId:    req.UserId,
		AutoRenew: req.AutoRenew,
	})
	if err != nil {
		l.Errorf("调用RPC服务失败: %v", err)
		return &types.EmptyResp{}, err
	}

	return &types.EmptyResp{}, nil
}
