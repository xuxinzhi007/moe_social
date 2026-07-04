package transport

import (
	"net/http"
	"strings"

	"backend/internal/apilegacy/common"
	"backend/internal/legacy/types"
	moeadmin "backend/internal/service/moe"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerAppRoutes(r *khttp.Router, admin *moeadmin.AdminService) {
	if r == nil {
		return
	}
	r.POST("/api/moe/runtimes/{agent_key}/trigger", triggerMoeRuntime(admin))
}

func triggerMoeRuntime(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.Result(http.StatusServiceUnavailable, &types.AdminRunMoeAgentResp{
				BaseResp: types.BaseResp{Code: -1, Message: "MoeAdmin unavailable", Success: false},
			})
		}

		var req types.AdminRunMoeAgentReq
		if err := ctx.BindQuery(&req); err != nil {
			return err
		}
		req.AgentKey = ctx.Vars().Get("agent_key")

		agentKey := strings.TrimSpace(req.AgentKey)
		if agentKey == "" {
			return ctx.Result(http.StatusBadRequest, &types.AdminRunMoeAgentResp{
				BaseResp: types.BaseResp{Code: -1, Message: "agent_key is required", Success: false},
			})
		}

		actorUID, err := common.UserIDUint(ctx.Request().Context())
		if err != nil {
			return ctx.Result(http.StatusUnauthorized, &types.AdminRunMoeAgentResp{
				BaseResp: types.BaseResp{Code: -1, Message: "login required", Success: false},
			})
		}

		rt, err := admin.FindRuntimeByAgentKey(ctx.Request().Context(), agentKey)
		if err != nil {
			return ctx.Result(http.StatusInternalServerError, &types.AdminRunMoeAgentResp{
				BaseResp: common.HandleError(err),
			})
		}
		if rt == nil {
			return ctx.Result(http.StatusNotFound, &types.AdminRunMoeAgentResp{
				BaseResp: types.BaseResp{Code: -1, Message: "AI runtime not found", Success: false},
			})
		}
		if !canTriggerRuntime(rt, actorUID) {
			return ctx.Result(http.StatusForbidden, &types.AdminRunMoeAgentResp{
				BaseResp: types.BaseResp{Code: -1, Message: "permission denied", Success: false},
			})
		}

		out, err := admin.RunAgentOnce(ctx.Request().Context(), agentKey, true)
		if err != nil {
			return ctx.Result(http.StatusInternalServerError, &types.AdminRunMoeAgentResp{
				BaseResp: common.HandleError(err),
			})
		}

		return ctx.Result(http.StatusOK, &types.AdminRunMoeAgentResp{
			BaseResp: common.HandleError(nil),
			Data: types.AdminRunMoeAgentData{
				AgentKey:       agentKey,
				Ok:             out.Accepted || out.AlreadyRunning,
				Detail:         triggerDetail(out),
				Accepted:       out.Accepted,
				AlreadyRunning: out.AlreadyRunning,
			},
		})
	}
}

func canTriggerRuntime(rt *model.MoeAgentRuntime, actorUID uint) bool {
	if rt == nil || actorUID == 0 {
		return false
	}
	return rt.BotUserID == actorUID
}

func triggerDetail(out moeadmin.RunOnceInvokeResult) string {
	if out.AlreadyRunning {
		return "AI is already running"
	}
	if out.Accepted {
		return "AI trigger accepted"
	}
	return "AI trigger failed"
}
