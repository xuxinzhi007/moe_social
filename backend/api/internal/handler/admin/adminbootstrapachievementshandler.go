package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminBootstrapAchievementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := func(req *types.EmptyReq) (resp *types.AdminBootstrapAchievementsResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminBootstrapAchievements(ctx, &moe.AdminBootstrapAchievementsReq{})
			if err != nil {
			return &types.AdminBootstrapAchievementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			msg := "成就表已有数据，未导入"
			if rpcResp.GetCreated() > 0 {
			msg = "已导入默认成就定义"
			}
			resp = &types.AdminBootstrapAchievementsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapAchievementsData{Created: int(rpcResp.GetCreated())},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "achievement", "", "导入默认成就定义")
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
