package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListMemoriesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListMemoriesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListMemoriesReq) (*types.AdminListMemoriesResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListMemories(ctx, &moe.AdminListMemoriesReq{
			Page:       int32(req.Page),
			PageSize:   int32(req.PageSize),
			UserId:     req.UserId,
			Keyword:    req.Keyword,
			MemoryType: req.MemoryType,
			})
			if err != nil {
			return &types.AdminListMemoriesResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminMemoryItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminMemoryToTypes(item)
			}
			return &types.AdminListMemoriesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListMemoriesData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
