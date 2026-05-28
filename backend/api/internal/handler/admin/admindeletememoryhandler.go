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

func AdminDeleteMemoryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteMemoryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteMemoryReq) (*types.AdminDeleteMemoryResp, error) {
			_, err := svcCtx.AdminGW.AdminDeleteMemory(ctx, &moe.AdminDeleteMemoryReq{
			MemoryId: req.MemoryId,
			})
			if err != nil {
			return &types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			resp := &types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(nil, "ok")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "user_memory", fmt.Sprintf("%d", req.MemoryId), "删除用户记忆")
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
