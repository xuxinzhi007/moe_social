package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetUserHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminGetUserResp{BaseResp: *br})
			return
		}
		var req types.AdminGetUserReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetUserReq) (resp *types.AdminGetUserResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetUser(r.Context(), &moe.AdminGetUserReq{
			UserId: req.UserId,
			})
			if err != nil {
			return &types.AdminGetUserResp{
			BaseResp: common.HandleRPCError(err, ""),
			}, nil
			}

			return &types.AdminGetUserResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcUserToTypes(rpcResp.User),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
