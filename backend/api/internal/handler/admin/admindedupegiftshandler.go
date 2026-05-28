package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDedupeGiftsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (resp *types.AdminDedupeGiftsResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminDedupeGifts(r.Context(), &moe.AdminDedupeGiftsReq{})
			if err != nil {
			return &types.AdminDedupeGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			msg := "未发现重复礼物"
			if rpcResp.GetRemoved() > 0 {
			msg = "已合并重复礼物"
			}
			resp = &types.AdminDedupeGiftsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminDedupeGiftsData{Removed: int(rpcResp.GetRemoved())},
			}
			if resp.BaseResp.Success && rpcResp.GetRemoved() > 0 {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "dedupe", "gift", "", "合并同名礼物")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
