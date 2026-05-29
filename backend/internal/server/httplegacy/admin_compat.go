package httplegacy

import (
	"net/http"
	"net/url"

	"backend/internal/apilegacy/common"
	"backend/internal/apilegacy/moebridge"
	"backend/internal/legacy/types"
	moeadmin "backend/internal/service/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterAdminCompat D2：MoeAdmin 已迁入 RegisterMoeAdminHTTPServer。
func RegisterAdminCompat(srv *khttp.Server, admin *moeadmin.AdminService) {
	_ = srv
	_ = admin
}

func adminListRuntimes(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rows, err := admin.ListRuntimes(ctx)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMoeRuntimesResp{
				BaseResp: common.HandleError(err),
			})
		}
		items := make([]types.MoeAgentRuntimeItem, 0, len(rows))
		for _, rt := range rows {
			items = append(items, moebridge.RuntimeItemFromModel(rt))
		}
		return ctx.JSON(http.StatusOK, types.AdminListMoeRuntimesResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminListMoeRuntimesData{Items: items},
		})
	}
}

func adminGetBrainPipeline(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		agentKey, _ := queryAgentKey(ctx.Request().URL)
		if agentKey == "" {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(errAgentKeyRequired),
			})
		}
		snap, err := admin.GetBrainPipeline(ctx, agentKey)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(err),
			})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainPipelineResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.PipelineDataFromBiz(snap),
		})
	}
}

func queryAgentKey(u *url.URL) (string, error) {
	if u == nil {
		return "", nil
	}
	return u.Query().Get("agent_key"), nil
}
