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

func AdminListVipOrdersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListVipOrdersResp{BaseResp: *br})
			return
		}
		var req types.AdminListVipOrdersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListVipOrdersReq) (resp *types.AdminListVipOrdersResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rpcResp, err := svcCtx.AdminGW.AdminListVipOrders(r.Context(), &moe.AdminListVipOrdersReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			UserId:   req.UserId,
			Keyword:  req.Keyword,
			Status:   req.Status,
			})
			if err != nil {
			return &types.AdminListVipOrdersResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.VipOrder, 0, len(rpcResp.GetOrders()))
			for _, o := range rpcResp.GetOrders() {
			items = append(items, common.RpcVipOrderToTypes(o))
			}

			return &types.AdminListVipOrdersResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListVipOrdersData{
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
