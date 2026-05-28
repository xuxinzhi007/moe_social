package moehttp

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/types"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterAdminReadonlyCompat Admin 只读 HTTP（PK-3：dashboard / growth / schema）。
func RegisterAdminReadonlyCompat(srv *khttp.Server, app *adminapp.AppService) {
	if srv == nil || app == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/admin/dashboard", adminDashboard(app))
	r.GET("/api/admin/growth/stats", adminGrowthStats(app))
	r.GET("/api/admin/schema/catalog", adminSchemaCatalog(app))
}

func adminDashboard(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.Dashboard(ctx, &moe.AdminDashboardReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDashboardResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminDashboardResp{
			BaseResp: common.HandleError(nil),
			Data: types.AdminDashboardData{
				LandingFeedbackTotal: int(rpcResp.GetLandingFeedbackTotal()),
				UserTotal:            int(rpcResp.GetUserTotal()),
				ServerTime:           rpcResp.GetServerTime(),
				FeishuEnabled:        rpcResp.GetFeishuEnabled(),
			},
		})
	}
}

func adminGrowthStats(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.GrowthStats(ctx)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetGrowthStatsResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetGrowthStatsResp{
			BaseResp: common.HandleError(nil),
			Data:     common.RpcAdminGrowthStatsToTypes(rpcResp.GetStats()),
		})
	}
}

func adminSchemaCatalog(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.SchemaCatalog(ctx)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminSchemaCatalogResp{BaseResp: common.HandleError(err)})
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
		data := types.AdminSchemaCatalogData{Items: items}
		if summary := rpcResp.GetSummary(); summary != nil {
			data.Summary = types.AdminSchemaCatalogSummary{
				TotalTables:    int(summary.GetTotalTables()),
				ManagedFull:    int(summary.GetManagedFull()),
				ManagedPartial: int(summary.GetManagedPartial()),
				Unmanaged:      int(summary.GetUnmanaged()),
				TotalRows:      summary.GetTotalRows(),
			}
		}
		return ctx.JSON(http.StatusOK, types.AdminSchemaCatalogResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
		})
	}
}
