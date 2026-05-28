package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminExportAiChatMessagesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminExportAiChatMessagesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminExportAiChatMessagesReq) (*types.AdminExportAiChatMessagesResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminExportAiChatMessages(r.Context(), &moe.AdminExportAiChatMessagesReq{
			UserId:    req.UserId,
			SessionId: req.SessionId,
			Role:      req.Role,
			Keyword:   req.Keyword,
			From:      req.From,
			To:        req.To,
			Limit:     int32(req.Limit),
			})
			if err != nil {
			return &types.AdminExportAiChatMessagesResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminExportAiChatMessagesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminExportAiChatMessagesData{
			Csv:       rpcResp.GetCsv(),
			RowCount:  int(rpcResp.GetRowCount()),
			Truncated: rpcResp.GetTruncated(),
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
