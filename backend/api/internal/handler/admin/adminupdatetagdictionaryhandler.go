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

func AdminUpdateTagDictionaryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminUpdateTagDictionaryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateTagDictionaryReq) (*types.AdminUpdateTagDictionaryResp, error) {
			entryID, err := handlerutil.ParseAdminPathID(req.EntryId)
			if err != nil {
			return &types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")}, nil
			}
			rpcReq := &moe.AdminUpdateTagDictionaryReq{
			EntryId:       entryID,
			Category:      req.Category,
			Tag:           req.Tag,
			Label:         req.Label,
			Note:          req.Note,
			SortOrder:     int32(req.SortOrder),
			Enabled:       req.Enabled,
			UpdateEnabled: req.UpdateEnabled,
			}
			rpcResp, err := svcCtx.AdminGW.AdminUpdateTagDictionary(r.Context(), rpcReq)
			if err != nil {
			return &types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "update", "tag_dictionary", req.EntryId, "更新 Bot 策略标签")
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
