package adminbiz

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"time"

	"backend/devports"
	"backend/pkg/processmem"
)

// RuntimeProcessInfo 单进程运行时指标。
type RuntimeProcessInfo struct {
	Role        string
	Pid         int
	GoAllocMb   float64
	GoSysMb     float64
	RssMb       float64
	Goroutines  int
	NumCpu      int
	Reachable   bool
	SameProcess bool
}

// RuntimeOverviewResult API/RPC 进程内存与布局汇总。
type RuntimeOverviewResult struct {
	ApiProcess       RuntimeProcessInfo
	RpcProcess       RuntimeProcessInfo
	RpcMonitorOnline bool
	Layout           string
	ProcessesNote    string
	EstimatedRssMb   float64
}

// RuntimeOverview 汇总 API/RPC 进程内存与布局信息。
func RuntimeOverview(ctx context.Context) (*RuntimeOverviewResult, error) {
	_ = ctx
	apiSnap := processmem.Current()
	apiInfo := RuntimeProcessInfo{
		Role:       "api",
		Pid:        apiSnap.PID,
		GoAllocMb:  round2(apiSnap.GoAllocMB),
		GoSysMb:    round2(apiSnap.GoSysMB),
		RssMb:      round2(apiSnap.RSSMB),
		Goroutines: apiSnap.Goroutines,
		NumCpu:     apiSnap.NumCPU,
		Reachable:  true,
	}

	rpcInfo := RuntimeProcessInfo{Role: "rpc", Reachable: false}
	layout := "split"
	note := "make dev 模式：API、RPC、deploy-agent 为独立进程，RSS 为各进程物理内存之和的近似值。"
	estimated := apiInfo.RssMb

	if live, ok := fetchRPCDebugLive(ctx); ok {
		rpcInfo.Reachable = true
		if pid, ok := live["pid"].(float64); ok {
			rpcInfo.Pid = int(pid)
		}
		if proc, ok := live["process"].(map[string]any); ok {
			rpcInfo.GoAllocMb = round2(asFloat(proc["go_alloc_mb"]))
			rpcInfo.GoSysMb = round2(asFloat(proc["go_sys_mb"]))
			rpcInfo.RssMb = round2(asFloat(proc["rss_mb"]))
			rpcInfo.Goroutines = int(asFloat(proc["goroutines"]))
			rpcInfo.NumCpu = int(asFloat(proc["num_cpu"]))
			if rpcInfo.Pid == 0 {
				rpcInfo.Pid = int(asFloat(proc["pid"]))
			}
		}
		if g, ok := live["goroutines"].(float64); ok && rpcInfo.Goroutines == 0 {
			rpcInfo.Goroutines = int(g)
		}
		if apiInfo.Pid > 0 && rpcInfo.Pid > 0 && apiInfo.Pid == rpcInfo.Pid {
			layout = "moe-social"
			note = "make moe-social 单进程：API 与 RPC 共用同一 OS 进程，下方 RPC 指标与 API 为同一份内存。"
			apiInfo.SameProcess = true
			rpcInfo.SameProcess = true
			estimated = apiInfo.RssMb
		} else {
			estimated = apiInfo.RssMb + rpcInfo.RssMb
			note = note + " deploy-agent（:19010）另有约数十 MB，未计入。"
		}
	} else {
		note = "RPC debug（:19011）未就绪。请使用 make moe-social / make dev -monitor=true 启动。"
	}

	return &RuntimeOverviewResult{
		ApiProcess:       apiInfo,
		RpcProcess:       rpcInfo,
		RpcMonitorOnline: rpcInfo.Reachable,
		Layout:           layout,
		ProcessesNote:    note,
		EstimatedRssMb:   round2(estimated),
	}, nil
}

func fetchRPCDebugLive(ctx context.Context) (map[string]any, bool) {
	url := devports.RpcDebugUpstream() + "/debug/live"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, false
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, false
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, false
	}
	var out map[string]any
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, false
	}
	return out, true
}

func asFloat(v any) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case int:
		return float64(n)
	case int64:
		return float64(n)
	default:
		return 0
	}
}

func round2(v float64) float64 {
	if v <= 0 {
		return 0
	}
	return float64(int(v*100+0.5)) / 100
}
