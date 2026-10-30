package moebridge

import (
	moebiz "backend/internal/biz/moe"
)

// MoeHostMetrics 推理与主机资源指标。
type MoeHostMetrics struct {
	ProcAllocMB      int64  `json:"proc_alloc_mb,optional"`
	ProcSysMB        int64  `json:"proc_sys_mb,optional"`
	NumCPU           int    `json:"num_cpu,optional"`
	NumGoroutine     int    `json:"num_goroutine,optional"`
	InferenceOnline  bool   `json:"inference_online,optional"`
	InferenceBaseURL string `json:"inference_base_url,optional"`
	InferenceModels  int    `json:"inference_models,optional"`
	GpuNote          string `json:"gpu_note,optional"`
}

// MoeGenAttemptItem 生成重试项。
type MoeGenAttemptItem struct {
	Attempt int    `json:"attempt"`
	Outcome string `json:"outcome"`
	Snippet string `json:"snippet,optional"`
	Note    string `json:"note,optional"`
}

// MoePipelineStepItem 管线步骤项。
type MoePipelineStepItem struct {
	Key        string `json:"key"`
	Label      string `json:"label"`
	Status     string `json:"status"`
	Detail     string `json:"detail,optional"`
	DurationMs int64  `json:"duration_ms,optional"`
}

// MoePipelineToolInvokeItem 管线工具调用项。
type MoePipelineToolInvokeItem struct {
	Tool      string `json:"tool"`
	Ok        bool   `json:"ok"`
	LatencyMs int    `json:"latency_ms,optional"`
	CreatedAt string `json:"created_at,optional"`
}

// AdminGetMoeBrainPipelineData Moe 大脑管线实时状态。
type AdminGetMoeBrainPipelineData struct {
	AgentKey         string                      `json:"agent_key"`
	RunAt            string                      `json:"run_at,optional"`
	Ok               bool                        `json:"ok"`
	Detail           string                      `json:"detail,optional"`
	PostId           string                      `json:"post_id,optional"`
	TotalDurationMs  int64                       `json:"total_duration_ms,optional"`
	HostMetrics      MoeHostMetrics              `json:"host_metrics,optional"`
	GenerateAttempts []MoeGenAttemptItem         `json:"generate_attempts,optional"`
	Steps            []MoePipelineStepItem       `json:"steps"`
	ToolsInvoked     []MoePipelineToolInvokeItem `json:"tools_invoked,optional"`
	StabilityScore   int                         `json:"stability_score,optional"`
	StabilityDelta   int                         `json:"stability_delta,optional"`
	RunFeedback      string                      `json:"run_feedback,optional"`
	Running          bool                        `json:"running,optional"`
	CurrentPhase     string                      `json:"current_phase,optional"`
	RunStartedAt     string                      `json:"run_started_at,optional"`
	ActiveStepKey    string                      `json:"active_step_key,optional"`
}

// PipelineDataFromBiz 将 biz 快照转换为管线 JSON 数据。
func PipelineDataFromBiz(snap moebiz.PipelineSnapshot) AdminGetMoeBrainPipelineData {
	data := AdminGetMoeBrainPipelineData{
		AgentKey:        snap.AgentKey,
		Ok:              snap.OK,
		Detail:          snap.Detail,
		PostId:          snap.PostID,
		TotalDurationMs: snap.TotalDurationMS,
		Running:         snap.Running,
		CurrentPhase:    snap.CurrentPhase,
		ActiveStepKey:   snap.ActiveStepKey,
		Steps:           make([]MoePipelineStepItem, 0, len(snap.Steps)),
	}
	if snap.HasRun {
		data.RunAt = snap.RunAt.Format("2006-01-02 15:04:05")
	}
	if !snap.RunStartedAt.IsZero() {
		data.RunStartedAt = snap.RunStartedAt.Format("2006-01-02 15:04:05")
	}
	m := snap.Metrics
	if m.NumCPU != 0 || m.ProcAllocMB != 0 || m.InferenceOnline || m.GpuNote != "" {
		data.HostMetrics = MoeHostMetrics{
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
	for _, a := range snap.GenerateAttempts {
		data.GenerateAttempts = append(data.GenerateAttempts, MoeGenAttemptItem{
			Attempt: a.Attempt,
			Outcome: a.Outcome,
			Snippet: a.Snippet,
			Note:    a.Note,
		})
	}
	for _, s := range snap.Steps {
		data.Steps = append(data.Steps, MoePipelineStepItem{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMs: s.DurationMS,
		})
	}
	for _, t := range snap.ToolsInvoked {
		data.ToolsInvoked = append(data.ToolsInvoked, MoePipelineToolInvokeItem{
			Tool:      t.Tool,
			Ok:        t.Ok,
			LatencyMs: t.LatencyMs,
			CreatedAt: t.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	data.StabilityScore = snap.StabilityScore
	data.StabilityDelta = snap.StabilityDelta
	data.RunFeedback = snap.RunFeedback
	data.Running = snap.Running
	data.CurrentPhase = snap.CurrentPhase
	data.ActiveStepKey = snap.ActiveStepKey
	if snap.Running && !snap.RunStartedAt.IsZero() {
		data.RunStartedAt = snap.RunStartedAt.Format("2006-01-02 15:04:05")
	}
	return data
}
