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

func AdminListUsersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListUsersResp{BaseResp: *br})
			return
		}
		var req types.AdminListUsersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListUsersReq) (resp *types.AdminListUsersResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 20
			}

			rpcResp, err := svcCtx.AdminGW.AdminListUsers(r.Context(), &moe.AdminListUsersReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListUsersResp{
			BaseResp: common.HandleRPCError(err, ""),
			}, nil
			}

			items := make([]types.User, 0, len(rpcResp.Users))
			for _, u := range rpcResp.Users {
			items = append(items, common.RpcUserToTypes(u))
			}

			return &types.AdminListUsersResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListUsersData{
			Items: items,
			Total: int(rpcResp.Total),
			},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
