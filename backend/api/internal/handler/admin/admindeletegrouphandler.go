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

func AdminDeleteGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteGroupReq) (resp *types.AdminDeleteGroupResp, err error) {
			_, err = svcCtx.AdminGW.AdminDeleteGroup(ctx, &moe.AdminDeleteGroupReq{
			GroupId: req.GroupId,
			})
			if err != nil {
			return &types.AdminDeleteGroupResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp = &types.AdminDeleteGroupResp{
			BaseResp: common.HandleRPCError(nil, "已删除"),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "group", req.GroupId, "删除群组")
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
