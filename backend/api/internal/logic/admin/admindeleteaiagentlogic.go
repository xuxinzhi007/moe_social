package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAiAgentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAiAgentLogic {
	return &AdminDeleteAiAgentLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteAiAgentLogic) AdminDeleteAiAgent(req *types.AdminDeleteAiAgentReq) (*types.AdminDeleteAiAgentResp, error) {
	_, err := l.svcCtx.AdminGW.AdminDeleteAiAgent(l.ctx, &super.AdminDeleteAiAgentReq{
		UserId:  req.UserId,
		AgentId: req.AgentId,
	})
	if err != nil {
		return &types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "ai_agent", req.AgentId, "删除 AI 分身")
	}
	return resp, nil
}
