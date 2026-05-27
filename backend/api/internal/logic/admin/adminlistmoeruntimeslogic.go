package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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
	rows, err := l.svcCtx.MoeGW.ListRuntimes(l.ctx)
	if err != nil {
		return &types.AdminListMoeRuntimesResp{BaseResp: common.HandleError(err)}, nil
	}
	items := make([]types.MoeAgentRuntimeItem, 0, len(rows))
	for _, rt := range rows {
		items = append(items, moebridge.RuntimeItemFromModel(rt))
	}
	return &types.AdminListMoeRuntimesResp{
		BaseResp: common.HandleError(nil),
		Data:     types.AdminListMoeRuntimesData{Items: items},
	}, nil
}
