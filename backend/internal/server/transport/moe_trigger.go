package transport

import (
	"net/http"
	"strings"

	apicomm "backend/internal/platform/apicomm"
	moeadmin "backend/internal/service/moe"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type runMoeAgentReq struct {
	AgentKey string `path:"agent_key"`
	Async    bool   `form:"async,optional"`
}

type runMoeAgentData struct {
	AgentKey       string `json:"agent_key"`
	Ok             bool   `json:"ok"`
	Detail         string `json:"detail"`
	PostId         string `json:"post_id,optional"`
	Accepted       bool   `json:"accepted,optional"`
	AlreadyRunning bool   `json:"already_running,optional"`
}

type runMoeAgentResp struct {
	apicomm.BaseResp
	Data runMoeAgentData `json:"data"`
}

func registerAppRoutes(r *khttp.Router, admin *moeadmin.AdminService) {
	if r == nil {
		return
	}
	r.POST("/api/moe/runtimes/{agent_key}/trigger", triggerMoeRuntime(admin))
}

func triggerMoeRuntime(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.Result(http.StatusServiceUnavailable, &runMoeAgentResp{
				BaseResp: apicomm.BaseResp{Code: -1, Message: "MoeAdmin unavailable", Success: false},
			})
		}

		var req runMoeAgentReq
		if err := ctx.BindQuery(&req); err != nil {
			return err
		}
		req.AgentKey = ctx.Vars().Get("agent_key")

		agentKey := strings.TrimSpace(req.AgentKey)
		if agentKey == "" {
			return ctx.Result(http.StatusBadRequest, &runMoeAgentResp{
				BaseResp: apicomm.BaseResp{Code: -1, Message: "agent_key is required", Success: false},
			})
		}

		actorUID, err := apicomm.UserIDUint(ctx.Request().Context())
		if err != nil {
			return ctx.Result(http.StatusUnauthorized, &runMoeAgentResp{
				BaseResp: apicomm.BaseResp{Code: -1, Message: "login required", Success: false},
			})
		}

		rt, err := admin.FindRuntimeByAgentKey(ctx.Request().Context(), agentKey)
		if err != nil {
			return ctx.Result(http.StatusInternalServerError, &runMoeAgentResp{
				BaseResp: apicomm.HandleError(err),
			})
		}
		if rt == nil {
			return ctx.Result(http.StatusNotFound, &runMoeAgentResp{
				BaseResp: apicomm.BaseResp{Code: -1, Message: "AI runtime not found", Success: false},
			})
		}
		if !canTriggerRuntime(rt, actorUID) {
			return ctx.Result(http.StatusForbidden, &runMoeAgentResp{
				BaseResp: apicomm.BaseResp{Code: -1, Message: "permission denied", Success: false},
			})
		}

		out, err := admin.RunAgentOnce(ctx.Request().Context(), agentKey, true)
		if err != nil {
			return ctx.Result(http.StatusInternalServerError, &runMoeAgentResp{
				BaseResp: apicomm.HandleError(err),
			})
		}

		return ctx.Result(http.StatusOK, &runMoeAgentResp{
			BaseResp: apicomm.HandleError(nil),
			Data: runMoeAgentData{
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
