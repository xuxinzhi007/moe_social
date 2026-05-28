package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"encoding/json"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminUpdateAiAgentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateAiAgentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateAiAgentReq) (*types.AdminUpdateAiAgentResp, error) {
			uid := strings.TrimSpace(req.UserId)
			aid := strings.TrimSpace(req.AgentId)
			payload := strings.TrimSpace(req.PayloadJson)
			if uid == "" || aid == "" || payload == "" {
			return &types.AdminUpdateAiAgentResp{
			BaseResp: types.BaseResp{Success: false, Message: "user_id、agent_id、payload_json 均不能为空"},
			}, nil
			}
			if !json.Valid([]byte(payload)) {
			return &types.AdminUpdateAiAgentResp{
			BaseResp: types.BaseResp{Success: false, Message: "payload_json 不是合法 JSON"},
			}, nil
			}
			if svcCtx.AIGW == nil {
			return &types.AdminUpdateAiAgentResp{
			BaseResp: types.BaseResp{Success: false, Message: "AI 网关未就绪"},
			}, nil
			}
			_, err := svcCtx.AIGW.UpsertAiAgent(ctx, &moe.UpsertAiResourceReq{
			UserId:      uid,
			Id:          aid,
			PayloadJson: payload,
			})
			if err != nil {
			return &types.AdminUpdateAiAgentResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateAiAgentResp{BaseResp: common.HandleError(nil)}
			resp.BaseResp.Message = "保存成功"
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "ai_agent", aid, "管理台更新酒馆角色卡")
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
