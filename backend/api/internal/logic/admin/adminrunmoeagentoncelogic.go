package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminRunMoeAgentOnceLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminRunMoeAgentOnceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRunMoeAgentOnceLogic {
	return &AdminRunMoeAgentOnceLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminRunMoeAgentOnceLogic) AdminRunMoeAgentOnce(req *types.AdminRunMoeAgentReq) (*types.AdminRunMoeAgentResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	out, err := l.svcCtx.MoeGW.RunAgentOnce(l.ctx, agentKey, req.Async)
	if err != nil {
		return &types.AdminRunMoeAgentResp{BaseResp: common.HandleError(err)}, nil
	}
	data := types.AdminRunMoeAgentData{
		AgentKey:       agentKey,
		Accepted:       out.Accepted,
		AlreadyRunning: out.AlreadyRunning,
	}
	if !out.Accepted && !out.AlreadyRunning {
		data.Ok = out.Result.OK
		data.Detail = out.Result.Detail
		data.PostId = out.Result.PostID
		if data.AgentKey == "" {
			data.AgentKey = out.Result.AgentKey
		}
	}
	return &types.AdminRunMoeAgentResp{
		BaseResp: common.HandleError(nil),
		Data:     data,
	}, nil
}
