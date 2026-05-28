package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetSchemaCatalogHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (*types.AdminSchemaCatalogResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetSchemaCatalog(ctx, &moe.AdminGetSchemaCatalogReq{})
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
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
