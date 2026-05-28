package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteFollowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteFollowReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteFollowReq) (*types.AdminDeleteFollowResp, error) {
			_, err := svcCtx.AdminGW.AdminDeleteFollow(ctx, &moe.AdminDeleteFollowReq{
			FollowId: req.FollowId,
			})
			if err != nil {
			return &types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "follow", req.FollowId, "删除关注关系")
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
