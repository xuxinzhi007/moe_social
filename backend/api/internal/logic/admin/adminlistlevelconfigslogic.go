package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListLevelConfigsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListLevelConfigsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListLevelConfigsLogic {
	return &AdminListLevelConfigsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListLevelConfigsLogic) AdminListLevelConfigs(_ *types.EmptyReq) (*types.AdminListLevelConfigsResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListLevelConfigs(l.ctx, &super.AdminListLevelConfigsReq{})
	if err != nil {
		return &types.AdminListLevelConfigsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminLevelConfigItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminLevelConfigToTypes(item)
	}
	return &types.AdminListLevelConfigsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     items,
	}, nil
}
