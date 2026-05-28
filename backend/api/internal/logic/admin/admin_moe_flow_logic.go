package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBotFlowLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeBotFlowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBotFlowLogic {
	return &AdminGetMoeBotFlowLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetMoeBotFlowLogic) AdminGetMoeBotFlow(req *types.AdminGetMoeBotFlowReq) (*types.AdminGetMoeBotFlowResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	cfg, err := l.svcCtx.MoeGW.GetBotFlow(l.ctx, agentKey)
	if err != nil {
		return &types.AdminGetMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
	}
	cfg.AgentKey = agentKey
	return &types.AdminGetMoeBotFlowResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.FlowDataFromBiz(cfg),
	}, nil
}

type AdminUpsertMoeBotFlowLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpsertMoeBotFlowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMoeBotFlowLogic {
	return &AdminUpsertMoeBotFlowLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpsertMoeBotFlowLogic) AdminUpsertMoeBotFlow(req *types.AdminUpsertMoeBotFlowReq) (*types.AdminUpsertMoeBotFlowResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	in := moebridge.FlowConfigFromTypes(req)
	saved, err := l.svcCtx.MoeGW.UpsertBotFlow(l.ctx, agentKey, in)
	if err != nil {
		return &types.AdminUpsertMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
	}
	saved.AgentKey = agentKey
	return &types.AdminUpsertMoeBotFlowResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.FlowDataFromBiz(saved),
	}, nil
}

type AdminDeleteMoeBotFlowLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteMoeBotFlowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMoeBotFlowLogic {
	return &AdminDeleteMoeBotFlowLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteMoeBotFlowLogic) AdminDeleteMoeBotFlow(req *types.AdminDeleteMoeBotFlowReq) (*types.AdminDeleteMoeBotFlowResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	cfg, err := l.svcCtx.MoeGW.DeleteBotFlow(l.ctx, agentKey)
	if err != nil {
		return &types.AdminDeleteMoeBotFlowResp{BaseResp: common.HandleError(err)}, nil
	}
	cfg.AgentKey = agentKey
	return &types.AdminDeleteMoeBotFlowResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.FlowDataFromBiz(cfg),
	}, nil
}
