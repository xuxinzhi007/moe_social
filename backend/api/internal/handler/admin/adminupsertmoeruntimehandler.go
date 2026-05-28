package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
	moebiz "backend/internal/biz/moe"
)

func AdminUpsertMoeRuntimeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpsertMoeRuntimeReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpsertMoeRuntimeReq) (*types.AdminUpsertMoeRuntimeResp, error) {
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
			saved, err := svcCtx.MoeGW.UpsertRuntime(ctx, moebiz.UpsertRuntimeParams{
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
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
