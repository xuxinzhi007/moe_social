package admin

import (
	"context"
	"strings"

	moebiz "backend/internal/biz/moe"
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpsertMoeRuntimeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpsertMoeRuntimeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMoeRuntimeLogic {
	return &AdminUpsertMoeRuntimeLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpsertMoeRuntimeLogic) AdminUpsertMoeRuntime(req *types.AdminUpsertMoeRuntimeReq) (*types.AdminUpsertMoeRuntimeResp, error) {
	botUID, err := moebiz.ParseBotUserID(req.BotUserId)
	if err != nil {
		return &types.AdminUpsertMoeRuntimeResp{
			BaseResp: types.BaseResp{Code: 400, Message: err.Error(), Success: false},
		}, nil
	}
	quota := req.PostQuotaDaily
	if quota <= 0 {
		quota = 5
	}
	saved, err := l.svcCtx.MoeGW.UpsertRuntime(l.ctx, moebiz.UpsertRuntimeParams{
		AgentKey:          req.AgentKey,
		DisplayName:       req.DisplayName,
		BotUserID:         botUID,
		CapabilityTier:    req.CapabilityTier,
		ModelName:         req.ModelName,
		ProviderProfileID: req.ProviderProfileId,
		ToolsEnabled:      req.ToolsEnabled,
		PostQuotaDaily:    int(quota),
		Enabled:           req.Enabled,
		SystemPrompt:      strings.TrimSpace(req.SystemPrompt),
		PostRules:         strings.TrimSpace(req.PostRules),
		ForbiddenTags:     strings.TrimSpace(req.ForbiddenTags),
		PreferredTags:     strings.TrimSpace(req.PreferredTags),
		PostScheduleMode:  strings.TrimSpace(req.PostScheduleMode),
		ScheduleCron:      strings.TrimSpace(req.ScheduleCron),
	})
	if err != nil {
		return &types.AdminUpsertMoeRuntimeResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminUpsertMoeRuntimeResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.RuntimeItemFromModel(saved),
	}, nil
}
