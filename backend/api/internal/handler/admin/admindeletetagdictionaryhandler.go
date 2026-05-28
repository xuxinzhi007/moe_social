//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteTagDictionaryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminDeleteTagDictionaryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteTagDictionaryReq) (*types.AdminDeleteTagDictionaryResp, error) {
			entryID, err := handlerutil.ParseAdminPathID(req.EntryId)
			if err != nil {
			return &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")}, nil
			}
			_, err = svcCtx.AdminGW.AdminDeleteTagDictionary(r.Context(), &moe.AdminDeleteTagDictionaryReq{EntryId: entryID})
			if err != nil {
			return &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "delete", "tag_dictionary", req.EntryId, "删除 Bot 策略标签")
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
