package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListFriendRequestsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListFriendRequestsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListFriendRequestsReq) (*types.AdminListFriendRequestsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListFriendRequests(ctx, &moe.AdminListFriendRequestsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Status:   req.Status,
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListFriendRequestsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminFriendRequestItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminFriendRequestToTypes(item)
			}
			return &types.AdminListFriendRequestsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListFriendRequestsData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
