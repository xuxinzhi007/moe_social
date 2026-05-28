package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetUserProfileHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetUserProfileReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminGetUserProfileReq) (*types.AdminGetUserProfileResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetUserProfile(ctx, &moe.AdminGetUserProfileReq{
			UserId: req.UserId,
			})
			if err != nil {
			return &types.AdminGetUserProfileResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminGetUserProfileResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminUserProfileToTypes(rpcResp.GetData()),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
