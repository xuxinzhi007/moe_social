package runtime

import (
	"context"
	"runtime"
	"strings"
	"time"

	"backend/pkg/llminference"
)

// HostMetrics 管理台展示的试跑环境快照（RPC 进程 + 推理服务可达性）。
type HostMetrics struct {
	ProcAllocMB      int64  `json:"proc_alloc_mb"`
	ProcSysMB        int64  `json:"proc_sys_mb"`
	NumCPU           int    `json:"num_cpu"`
	NumGoroutine     int    `json:"num_goroutine"`
	InferenceOnline  bool   `json:"inference_online"`
	InferenceBaseURL string `json:"inference_base_url,omitempty"`
	InferenceModels  int    `json:"inference_models"`
	GpuNote          string `json:"gpu_note,omitempty"`
}

// SampleHostMetrics 采样当前 RPC 进程与统一推理端点列表（GPU 由推理端占用，此处仅备注）。
func SampleHostMetrics(ctx context.Context, inf llminference.Config) HostMetrics {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	out := HostMetrics{
		ProcAllocMB:  int64(ms.Alloc / 1024 / 1024),
		ProcSysMB:    int64(ms.Sys / 1024 / 1024),
		NumCPU:       runtime.NumCPU(),
		NumGoroutine: runtime.NumGoroutine(),
		GpuNote:      "GPU 显存由推理服务进程占用，请在启动推理的机器上查看",
	}
	base := strings.TrimSpace(inf.BaseURL)
	if base == "" {
		out.GpuNote = out.GpuNote + "；未配置 llm_inference.base_url"
		return out
	}
	out.InferenceBaseURL = base
	cctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	online, n := probeInferenceModels(cctx, inf)
	out.InferenceOnline = online
	out.InferenceModels = n
	return out
}

func probeInferenceModels(ctx context.Context, inf llminference.Config) (online bool, count int) {
	models, err := llminference.ListModels(ctx, inf)
	if err != nil {
		return false, 0
	}
	return true, len(models)
}
