package transport

import (
	"fmt"
	"net/http"
	"time"

	"backend/internal/biz/moe/moebridge"
	"backend/internal/legacy/types"
	apicomm "backend/internal/platform/apicomm"
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
		// GET + EventSource 不带 Content-Type，不能用 ctx.Bind（body 解码器会回 400 CODEC）；
		// 也不能用 ctx.BindQuery（它认 json tag，而这个 legacy 结构体只有 form tag）。
		agentKey := r.URL.Query().Get("agent_key")
		if agentKey == "" {
			_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: apicomm.HandleError(fmt.Errorf("agent_key is required")),
			})
			return nil
		}
		if admin == nil {
			_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: moeAdminUnavailable(),
			})
			return nil
		}

		apicomm.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		send := func() bool {
			snap, err := admin.GetBrainPipeline(r.Context(), agentKey)
			if err != nil {
				_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
					BaseResp: apicomm.HandleError(err),
				})
				return false
			}
			if err := apicomm.WriteSSE(w, "pipeline", types.AdminGetMoeBrainPipelineResp{
				BaseResp: apicomm.HandleError(nil),
				Data:     moebridge.PipelineDataFromBiz(snap),
			}); err != nil {
				return false
			}
			return !snap.Running
		}

		if send() {
			_ = apicomm.WriteSSE(w, "done", map[string]bool{"ok": true})
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
				if err := apicomm.WriteSSE(w, "ping", map[string]string{"t": "ok"}); err != nil {
					return nil
				}
			case _, open := <-updates:
				if !open {
					return nil
				}
				if send() {
					_ = apicomm.WriteSSE(w, "done", map[string]bool{"ok": true})
					return nil
				}
			}
		}
	}
}
