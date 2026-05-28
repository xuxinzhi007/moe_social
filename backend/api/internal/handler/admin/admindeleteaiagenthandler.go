package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteAiAgentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteAiAgentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteAiAgentReq) (*types.AdminDeleteAiAgentResp, error) {
			_, err := svcCtx.AdminGW.AdminDeleteAiAgent(ctx, &moe.AdminDeleteAiAgentReq{
			UserId:  req.UserId,
			AgentId: req.AgentId,
			})
			if err != nil {
			return &types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "ai_agent", req.AgentId, "删除 AI 分身")
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
