//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"fmt"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateLevelConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateLevelConfigReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateLevelConfigReq) (*types.AdminUpdateLevelConfigResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpdateLevelConfig(ctx, &moe.AdminUpdateLevelConfigReq{
			Id:               req.LevelId,
			Title:            req.Title,
			MinExp:           int32(req.MinExp),
			MaxExp:           int32(req.MaxExp),
			Privileges:       req.Privileges,
			BadgeUrl:         req.BadgeUrl,
			UpdateTitle:      req.UpdateTitle,
			UpdateMinExp:     req.UpdateMinExp,
			UpdateMaxExp:     req.UpdateMaxExp,
			UpdatePrivileges: req.UpdatePrivileges,
			UpdateBadgeUrl:   req.UpdateBadgeUrl,
			})
			if err != nil {
			return &types.AdminUpdateLevelConfigResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			resp := &types.AdminUpdateLevelConfigResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminLevelConfigToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "level_config", fmt.Sprintf("%d", req.LevelId), "更新等级配置")
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
