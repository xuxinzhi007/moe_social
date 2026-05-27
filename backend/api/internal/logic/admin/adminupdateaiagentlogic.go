package admin

import (
	"context"
	"encoding/json"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAiAgentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAiAgentLogic {
	return &AdminUpdateAiAgentLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateAiAgentLogic) AdminUpdateAiAgent(req *types.AdminUpdateAiAgentReq) (*types.AdminUpdateAiAgentResp, error) {
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
	if l.svcCtx.AIGW == nil {
		return &types.AdminUpdateAiAgentResp{
			BaseResp: types.BaseResp{Success: false, Message: "AI 网关未就绪"},
		}, nil
	}
	_, err := l.svcCtx.AIGW.UpsertAiAgent(l.ctx, &super.UpsertAiResourceReq{
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
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "ai_agent", aid, "管理台更新酒馆角色卡")
	}
	return resp, nil
}
