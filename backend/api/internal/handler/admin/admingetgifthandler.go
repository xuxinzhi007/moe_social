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

func AdminGetGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminGetGiftResp{BaseResp: *br})
			return
		}
		var req types.AdminGetGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetGiftReq) (resp *types.AdminGetGiftResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetGift(r.Context(), &moe.AdminGetGiftReq{
			GiftId: req.GiftId,
			})
			if err != nil {
			return &types.AdminGetGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminGetGiftResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
