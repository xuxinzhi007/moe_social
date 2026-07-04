package transport

import (
	"fmt"
	"net/http"
	"time"

	"backend/internal/apilegacy/common"
	"backend/internal/apilegacy/moebridge"
	"backend/internal/legacy/types"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/runtime"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerSSE(r *khttp.Router, admin *moeadmin.AdminService) {
	r.GET("/api/admin/moe/brain/pipeline/stream", streamMoeBrainPipeline(admin))
}

func moeAdminUnavailable() types.BaseResp {
	return types.BaseResp{Code: -1, Message: "MoeAdmin unavailable", Success: false}
}

func streamMoeBrainPipeline(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w := ctx.Response()
		r := ctx.Request()
		var req types.AdminGetMoeBrainPipelineReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		agentKey := req.AgentKey
		if agentKey == "" {
			_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(fmt.Errorf("agent_key is required")),
			})
			return nil
		}
		if admin == nil {
			_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: moeAdminUnavailable(),
			})
			return nil
		}

		common.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		send := func() bool {
			snap, err := admin.GetBrainPipeline(r.Context(), agentKey)
			if err != nil {
				_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
					BaseResp: common.HandleError(err),
				})
				return false
			}
			if err := common.WriteSSE(w, "pipeline", types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(nil),
				Data:     moebridge.PipelineDataFromBiz(snap),
			}); err != nil {
				return false
			}
			return !snap.Running
		}

		if send() {
			_ = common.WriteSSE(w, "done", map[string]bool{"ok": true})
			return nil
		}

		updates, unsub := runtime.LiveRuns.Subscribe(agentKey)
		defer unsub()

		heartbeat := time.NewTicker(25 * time.Second)
		defer heartbeat.Stop()

		for {
			select {
			case <-r.Context().Done():
				return nil
			case <-heartbeat.C:
				if err := common.WriteSSE(w, "ping", map[string]string{"t": "ok"}); err != nil {
					return nil
				}
			case _, open := <-updates:
				if !open {
					return nil
				}
				if send() {
					_ = common.WriteSSE(w, "done", map[string]bool{"ok": true})
					return nil
				}
			}
		}
	}
}
