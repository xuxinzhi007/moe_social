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

func AdminDeleteGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteGiftReq) (resp *types.AdminDeleteGiftResp, err error) {
			_, err = svcCtx.AdminGW.AdminDeleteGift(ctx, &moe.AdminDeleteGiftReq{
			GiftId: req.GiftId,
			})
			if err != nil {
			return &types.AdminDeleteGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp = &types.AdminDeleteGiftResp{
			BaseResp: common.HandleRPCError(nil, "已删除"),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "gift", req.GiftId, "删除礼物")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
