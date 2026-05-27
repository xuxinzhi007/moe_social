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
	result, err := l.svcCtx.MoeGW.RunAgentOnce(l.ctx, agentKey)
	if err != nil {
		return &types.AdminRunMoeAgentResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminRunMoeAgentResp{
		BaseResp: common.HandleError(nil),
		Data: types.AdminRunMoeAgentData{
			AgentKey: result.AgentKey,
			Ok:       result.OK,
			Detail:   result.Detail,
			PostId:   result.PostID,
		},
	}, nil
}
