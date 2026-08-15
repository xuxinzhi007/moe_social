package moebiz

import (
	"context"
	"strings"
	"time"

	"backend/internal/data/moedata"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
)

func pipelineFromLive(ctx context.Context, st MoeStore, agentKey string, live runtime.LiveRunSnapshot) PipelineSnapshot {
	db := dbFromStore(ctx, st)
	out := PipelineSnapshot{
		AgentKey:      agentKey,
		Running:       true,
		CurrentPhase:  live.CurrentPhase,
		RunStartedAt:  live.StartedAt,
		ActiveStepKey: live.ActiveKey,
		Steps:         nil,
	}
	steps := runtime.LiveRuns.PipelineStepsForAgent(agentKey)
	if len(steps) > 0 {
		out.Steps = make([]PipelineStep, 0, len(steps))
		for _, s := range steps {
			out.Steps = append(out.Steps, PipelineStep{
				Key: s.Key, Label: s.Label, Status: s.Status, Detail: s.Detail, DurationMS: s.MS,
			})
		}
	}
	out.TotalDurationMS = time.Since(live.StartedAt).Milliseconds()
	if len(live.GenerateAttempts) > 0 {
		out.GenerateAttempts = make([]GenAttemptView, 0, len(live.GenerateAttempts))
		for _, a := range live.GenerateAttempts {
			out.GenerateAttempts = append(out.GenerateAttempts, GenAttemptView{
				Attempt: a.Attempt,
				Outcome: string(a.Outcome),
				Snippet: a.Snippet,
				Note:    a.Note,
			})
		}
	}
	if db != nil {
		if invoked, err := toolaudit.ListInvokedSince(db, agentKey, live.StartedAt, 50); err == nil {
			for _, t := range invoked {
				out.ToolsInvoked = append(out.ToolsInvoked, ToolInvokeView{
					Tool: t.Tool, Ok: t.Ok, LatencyMs: t.LatencyMs, CreatedAt: t.CreatedAt,
				})
			}
		}
	}
	return out
}

// PipelineStep 单步流水线视图（与 proto / super 对齐）。
type PipelineStep struct {
	Key        string
	Label      string
	Status     string
	Detail     string
	DurationMS int64
}

// HostMetrics 试跑主机与推理快照。
type HostMetrics struct {
	ProcAllocMB      int64
	ProcSysMB        int64
	NumCPU           int
	NumGoroutine     int
	InferenceOnline  bool
	InferenceBaseURL string
	InferenceModels  int
	GpuNote          string
}

// GenAttemptView 本次试跑内的单次生成尝试（不跨历史请求累积）。
type GenAttemptView struct {
	Attempt int
	Outcome string
	Snippet string
	Note    string
}

// ToolInvokeView 时间窗内工具调用（供画布高亮）。
type ToolInvokeView struct {
	Tool      string
	Ok        bool
	LatencyMs int
	CreatedAt time.Time
}

// PipelineSnapshot 最近一次试跑流水线。
type PipelineSnapshot struct {
	AgentKey         string
	OK               bool
	Detail           string
	PostID           string
	RunAt            time.Time
	TotalDurationMS  int64
	Steps            []PipelineStep
	ToolsInvoked     []ToolInvokeView
	Metrics          HostMetrics
	GenerateAttempts []GenAttemptView
	StabilityScore   int
	StabilityDelta   int
	RunFeedback      string
	HasRun           bool
	// Running 试跑进行中（进程内 live 状态，供管理台轮询）。
	Running       bool
	CurrentPhase  string
	RunStartedAt  time.Time
	ActiveStepKey string
}

// GetBrainPipeline 返回指定 agent 最近一次试跑流水线；无记录时 steps 为空。
func GetBrainPipeline(ctx context.Context, st MoeStore, agentKey string) (PipelineSnapshot, error) {
	db := dbFromStore(ctx, st)
	key := strings.TrimSpace(agentKey)
	out := PipelineSnapshot{
		AgentKey: key,
		Steps:    nil,
	}
	if key == "" {
		return out, nil
	}
	if liveSnap, ok := runtime.LiveRuns.SnapshotForAgent(key); ok {
		return pipelineFromLive(ctx, st, key, liveSnap), nil
	}
	if db == nil {
		return out, nil
	}
	row, err := moedata.LatestAgentRunLog(db, key)
	if err != nil || row == nil {
		return out, err
	}
	bundle := moedata.ParseRunLog(row.StepsJSON)
	out.HasRun = true
	out.OK = row.OK
	out.Detail = row.Detail
	out.PostID = row.PostID
	out.RunAt = row.CreatedAt
	if invoked, err := toolaudit.ListInvokedSince(db, key, row.CreatedAt, 50); err == nil {
		for _, t := range invoked {
			out.ToolsInvoked = append(out.ToolsInvoked, ToolInvokeView{
				Tool: t.Tool, Ok: t.Ok, LatencyMs: t.LatencyMs, CreatedAt: t.CreatedAt,
			})
		}
	}
	out.TotalDurationMS = bundle.TotalMs
	out.Metrics = hostMetricsFromRuntime(bundle.Metrics)
	out.StabilityScore = bundle.StabilityScore
	out.StabilityDelta = bundle.StabilityDelta
	out.RunFeedback = bundle.RunFeedback
	if len(bundle.GenerateAttempts) > 0 {
		out.GenerateAttempts = make([]GenAttemptView, 0, len(bundle.GenerateAttempts))
		for _, a := range bundle.GenerateAttempts {
			out.GenerateAttempts = append(out.GenerateAttempts, GenAttemptView{
				Attempt: a.Attempt,
				Outcome: string(a.Outcome),
				Snippet: a.Snippet,
				Note:    a.Note,
			})
		}
	}
	if len(bundle.Steps) == 0 {
		return out, nil
	}
	out.Steps = make([]PipelineStep, 0, len(bundle.Steps))
	for _, s := range bundle.Steps {
		out.Steps = append(out.Steps, PipelineStep{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMS: s.MS,
		})
	}
	return out, nil
}

func hostMetricsFromRuntime(m runtime.HostMetrics) HostMetrics {
	return HostMetrics{
		ProcAllocMB:      m.ProcAllocMB,
		ProcSysMB:        m.ProcSysMB,
		NumCPU:           m.NumCPU,
		NumGoroutine:     m.NumGoroutine,
		InferenceOnline:  m.InferenceOnline,
		InferenceBaseURL: m.InferenceBaseURL,
		InferenceModels:  m.InferenceModels,
		GpuNote:          m.GpuNote,
	}
}
