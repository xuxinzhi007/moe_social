//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListMoeRuntimesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		resp, err := func() (*types.AdminListMoeRuntimesResp, error) {
			rows, err := svcCtx.MoeGW.ListRuntimes(ctx)
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
		}()
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
