package admin

import (
	"context"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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
	botUID, err := strconv.ParseUint(strings.TrimSpace(req.BotUserId), 10, 32)
	if err != nil || botUID == 0 {
		return &types.AdminUpsertMoeRuntimeResp{
			BaseResp: types.BaseResp{Code: 400, Message: "无效的 bot_user_id", Success: false},
		}, nil
	}
	quota := int32(req.PostQuotaDaily)
	if quota <= 0 {
		quota = 5
	}
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpsertMoeRuntime(l.ctx, &super.AdminUpsertMoeRuntimeReq{
		AgentKey:          strings.TrimSpace(req.AgentKey),
		DisplayName:       strings.TrimSpace(req.DisplayName),
		BotUserId:         strings.TrimSpace(req.BotUserId),
		CapabilityTier:    strings.TrimSpace(req.CapabilityTier),
		ModelName:         strings.TrimSpace(req.ModelName),
		ProviderProfileId: strings.TrimSpace(req.ProviderProfileId),
		ToolsEnabled:      req.ToolsEnabled,
		PostQuotaDaily:    quota,
		Enabled:           req.Enabled,
		SystemPrompt:      strings.TrimSpace(req.SystemPrompt),
		PostRules:         strings.TrimSpace(req.PostRules),
		ForbiddenTags:     strings.TrimSpace(req.ForbiddenTags),
		PreferredTags:     strings.TrimSpace(req.PreferredTags),
		PostScheduleMode:  strings.TrimSpace(req.PostScheduleMode),
		ScheduleCron:      strings.TrimSpace(req.ScheduleCron),
	})
	if err != nil {
		return &types.AdminUpsertMoeRuntimeResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminUpsertMoeRuntimeResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.RuntimeItemFromRPC(rpcResp.Item),
	}, nil
}
