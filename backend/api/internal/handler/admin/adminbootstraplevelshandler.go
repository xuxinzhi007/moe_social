//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminBootstrapLevelsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := func(req *types.EmptyReq) (*types.AdminBootstrapLevelsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminBootstrapLevels(ctx, &moe.AdminBootstrapLevelsReq{})
			if err != nil {
			return &types.AdminBootstrapLevelsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminBootstrapLevelsResp{
			BaseResp: common.HandleRPCError(nil, "初始化成功"),
			Data: types.AdminBootstrapLevelsData{
			LevelConfigsCreated:   int(rpcResp.GetLevelConfigsCreated()),
			CheckInRewardsCreated: int(rpcResp.GetCheckInRewardsCreated()),
			},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "level_config", "", "导入默认等级配置")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
