package runtime

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
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

// SampleHostMetrics 采样当前 RPC 进程与 llama-server 列表（GPU 由推理端占用，此处仅备注）。
func SampleHostMetrics(ctx context.Context, inf llminference.Config) HostMetrics {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	out := HostMetrics{
		ProcAllocMB: int64(ms.Alloc / 1024 / 1024),
		ProcSysMB:   int64(ms.Sys / 1024 / 1024),
		NumCPU:      runtime.NumCPU(),
		NumGoroutine: runtime.NumGoroutine(),
		GpuNote:     "GPU 显存由 llama-server 进程占用，请在启动推理的机器上用活动监视器 / nvidia-smi 查看",
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
	if !inf.Ready() {
		return false, 0
	}
	client := &http.Client{Timeout: 5 * time.Second}
	url := strings.TrimRight(inf.BaseURL, "/") + "/v1/models"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return false, 0
	}
	resp, err := client.Do(req)
	if err != nil {
		return false, 0
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, 0
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, 0
	}
	var parsed struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return true, 0
	}
	return true, len(parsed.Data)
}
