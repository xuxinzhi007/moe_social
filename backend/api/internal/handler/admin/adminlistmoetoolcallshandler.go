package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	moeadmin "backend/internal/service/moe"
	moebiz "backend/internal/biz/moe"
)

func AdminListMoeToolCallsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListMoeToolCallsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListMoeToolCallsReq) (*types.AdminListMoeToolCallsResp, error) {
			rows, total, err := svcCtx.MoeGW.ListToolCalls(ctx, moebiz.ToolCallsFilter{
			From:        moeadmin.ParseTimeFilter(req.From, false),
			To:          moeadmin.ParseTimeFilter(req.To, true),
			AgentKey:    req.AgentKey,
			Tool:        req.Tool,
			Source:      req.Source,
			ActorUserID: moebiz.ParseActorUserID(req.ActorUserId),
			OkOnly:      req.OkOnly,
			FailedOnly:  req.FailedOnly,
			Page:        req.Page,
			PageSize:    req.PageSize,
			})
			if err != nil {
			return &types.AdminListMoeToolCallsResp{BaseResp: common.HandleError(err)}, nil
			}
			return &types.AdminListMoeToolCallsResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.ToolCallsDataFromBiz(rows, total),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
