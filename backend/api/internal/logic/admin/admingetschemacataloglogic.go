package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetSchemaCatalogLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetSchemaCatalogLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetSchemaCatalogLogic {
	return &AdminGetSchemaCatalogLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetSchemaCatalogLogic) AdminGetSchemaCatalog(_ *types.EmptyReq) (*types.AdminSchemaCatalogResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetSchemaCatalog(l.ctx, &super.AdminGetSchemaCatalogReq{})
	if err != nil {
		return &types.AdminSchemaCatalogResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.AdminSchemaTableItem, 0, len(rpcResp.GetItems()))
	for _, it := range rpcResp.GetItems() {
		items = append(items, types.AdminSchemaTableItem{
			Key:          it.GetKey(),
			TableName:    it.GetTableName(),
			Label:        it.GetLabel(),
			Domain:       it.GetDomain(),
			Coverage:     it.GetCoverage(),
			Capabilities: it.GetCapabilities(),
			AdminRoute:   it.GetAdminRoute(),
			BootstrapKey: it.GetBootstrapKey(),
			RowCount:     it.GetRowCount(),
			Note:         it.GetNote(),
		})
	}

	summary := rpcResp.GetSummary()
	data := types.AdminSchemaCatalogData{Items: items}
	if summary != nil {
		data.Summary = types.AdminSchemaCatalogSummary{
			TotalTables:    int(summary.GetTotalTables()),
			ManagedFull:    int(summary.GetManagedFull()),
			ManagedPartial: int(summary.GetManagedPartial()),
			Unmanaged:      int(summary.GetUnmanaged()),
			TotalRows:      summary.GetTotalRows(),
		}
	}

	return &types.AdminSchemaCatalogResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     data,
	}, nil
}
