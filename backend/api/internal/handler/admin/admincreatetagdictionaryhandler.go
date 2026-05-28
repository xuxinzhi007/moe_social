package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminCreateTagDictionaryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminCreateTagDictionaryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminCreateTagDictionaryReq) (*types.AdminCreateTagDictionaryResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminCreateTagDictionary(r.Context(), &moe.AdminCreateTagDictionaryReq{
			Category:  req.Category,
			Tag:       req.Tag,
			Label:     req.Label,
			Note:      req.Note,
			SortOrder: int32(req.SortOrder),
			Enabled:   req.Enabled,
			})
			if err != nil {
			return &types.AdminCreateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminCreateTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "create", "tag_dictionary", resp.Data.Id, "创建 Bot 策略标签")
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
