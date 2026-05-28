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

func AdminDeletePostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeletePostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeletePostReq) (resp *types.AdminDeletePostResp, err error) {
			_, err = svcCtx.AdminGW.AdminDeletePost(ctx, &moe.AdminDeletePostReq{
			PostId: req.PostId,
			})
			if err != nil {
			return &types.AdminDeletePostResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp = &types.AdminDeletePostResp{
			BaseResp: common.HandleRPCError(nil, "已删除"),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "post", req.PostId, "删除帖子")
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
