package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMoeRuntimesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMoeRuntimesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMoeRuntimesLogic {
	return &AdminListMoeRuntimesLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListMoeRuntimesLogic) AdminListMoeRuntimes() (*types.AdminListMoeRuntimesResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListMoeRuntimes(l.ctx, &super.AdminListMoeRuntimesReq{})
	if err != nil {
		return &types.AdminListMoeRuntimesResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.MoeAgentRuntimeItem, 0, len(rpcResp.Items))
	for _, item := range rpcResp.Items {
		items = append(items, moebridge.RuntimeItemFromRPC(item))
	}
	return &types.AdminListMoeRuntimesResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListMoeRuntimesData{Items: items},
	}, nil
}
