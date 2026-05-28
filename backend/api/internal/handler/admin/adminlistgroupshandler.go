package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListGroupsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListGroupsResp{BaseResp: *br})
			return
		}
		var req types.AdminListGroupsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListGroupsReq) (resp *types.AdminListGroupsResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rpcResp, err := svcCtx.AdminGW.AdminListGroups(r.Context(), &moe.AdminListGroupsReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListGroupsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.Group, 0, len(rpcResp.GetGroups()))
			for _, g := range rpcResp.GetGroups() {
			items = append(items, common.RpcGroupToTypes(g))
			}

			return &types.AdminListGroupsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListGroupsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
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
