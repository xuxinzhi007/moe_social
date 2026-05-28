package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListGiftsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListGiftsResp{BaseResp: *br})
			return
		}
		var req types.AdminListGiftsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListGiftsReq) (resp *types.AdminListGiftsResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rpcResp, err := svcCtx.AdminGW.AdminListGifts(r.Context(), &moe.AdminListGiftsReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			Keyword:  req.Keyword,
			Category: req.Category,
			})
			if err != nil {
			return &types.AdminListGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.Gift, 0, len(rpcResp.GetGifts()))
			for _, g := range rpcResp.GetGifts() {
			items = append(items, common.RpcGiftToTypes(g))
			}

			return &types.AdminListGiftsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListGiftsData{
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
