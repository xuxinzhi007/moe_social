package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListFollowsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListFollowsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListFollowsReq) (*types.AdminListFollowsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListFollows(ctx, &moe.AdminListFollowsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Keyword:  req.Keyword,
			UserId:   req.UserId,
			})
			if err != nil {
			return &types.AdminListFollowsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminFollowItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminFollowToTypes(item)
			}
			return &types.AdminListFollowsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListFollowsData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
