package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListTagDictionaryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminListTagDictionaryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListTagDictionaryReq) (*types.AdminListTagDictionaryResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListTagDictionary(r.Context(), &moe.AdminListTagDictionaryReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Category: req.Category,
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminTagDictionaryItem, 0, len(rpcResp.GetItems()))
			for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminTagDictionaryToTypes(row))
			}
			return &types.AdminListTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListTagDictionaryData{
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
