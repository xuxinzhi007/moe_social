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

func AdminBootstrapGiftsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (resp *types.AdminBootstrapGiftsResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminBootstrapGifts(ctx, &moe.AdminBootstrapGiftsReq{})
			if err != nil {
			return &types.AdminBootstrapGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			msg := "礼物表已有数据，未导入"
			if rpcResp.GetCreated() > 0 {
			msg = "已导入默认礼物"
			}
			resp = &types.AdminBootstrapGiftsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapGiftsData{Created: int(rpcResp.GetCreated())},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "gift", "", "导入默认礼物")
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
