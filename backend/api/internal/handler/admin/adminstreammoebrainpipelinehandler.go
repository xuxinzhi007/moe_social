package admin

import (
	"fmt"
	"net/http"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/runtime"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// AdminStreamMoeBrainPipelineHandler SSE：试跑流水线实时推送（替代轮询）。
func AdminStreamMoeBrainPipelineHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetMoeBrainPipelineReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		agentKey := req.AgentKey
		if agentKey == "" {
			_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(fmt.Errorf("agent_key is required")),
			})
			return
		}

		common.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		send := func() bool {
			if svcCtx.MoeGW == nil {
				_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
					BaseResp: types.BaseResp{Code: -1, Message: "MoeGW 未配置", Success: false},
				})
				return false
			}
			snap, err := svcCtx.MoeGW.GetBrainPipeline(ctx, agentKey)
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
			return
		}

		updates, unsub := runtime.LiveRuns.Subscribe(agentKey)
		defer unsub()

		heartbeat := time.NewTicker(25 * time.Second)
		defer heartbeat.Stop()

		for {
			select {
			case <-r.Context().Done():
				return
			case <-heartbeat.C:
				if err := common.WriteSSE(w, "ping", map[string]string{"t": "ok"}); err != nil {
					return
				}
			case _, open := <-updates:
				if !open {
					return
				}
				if send() {
					_ = common.WriteSSE(w, "done", map[string]bool{"ok": true})
					return
				}
			}
		}
	}
}
