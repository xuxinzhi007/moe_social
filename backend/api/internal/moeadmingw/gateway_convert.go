package moeadmingw

import (
	"strconv"
	"time"

	moebiz "backend/internal/biz/moe"
	"backend/api/internal/moebridge"
	"backend/api/internal/types"
	moepb "backend/api/moe/v1"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/toolaudit"
	"backend/rpc/pb/super"
)

func runtimeModelFromProto(item *moepb.AgentRuntime) model.MoeAgentRuntime {
	t := moebridge.RuntimeItemFromProto(item)
	botUID, _ := moebiz.ParseBotUserID(t.BotUserId)
	return model.MoeAgentRuntime{
		AgentKey:          t.AgentKey,
		DisplayName:       t.DisplayName,
		BotUserID:         botUID,
		CapabilityTier:    t.CapabilityTier,
		ModelName:         t.ModelName,
		ProviderProfileID: t.ProviderProfileId,
		ToolsEnabled:      t.ToolsEnabled,
		PostQuotaDaily:    t.PostQuotaDaily,
		Enabled:           t.Enabled,
		SystemPrompt:      t.SystemPrompt,
		PostRules:         t.PostRules,
		ForbiddenTags:     t.ForbiddenTags,
		PreferredTags:     t.PreferredTags,
		PostScheduleMode:  t.PostScheduleMode,
		ScheduleCron:      t.ScheduleCron,
	}
}

func pipelineFromProto(d *moepb.GetBrainPipelineReply) moebiz.PipelineSnapshot {
	if d == nil {
		return moebiz.PipelineSnapshot{}
	}
	snap := moebiz.PipelineSnapshot{
		AgentKey:        d.GetAgentKey(),
		OK:              d.GetOk(),
		Detail:          d.GetDetail(),
		PostID:          d.GetPostId(),
		TotalDurationMS: d.GetTotalDurationMs(),
	}
	if runAt := d.GetRunAt(); runAt != "" {
		if t, err := time.ParseInLocation("2006-01-02 15:04:05", runAt, time.Local); err == nil {
			snap.RunAt = t
			snap.HasRun = true
		}
	}
	if hm := d.GetHostMetrics(); hm != nil {
		snap.Metrics = moebiz.HostMetrics{
			ProcAllocMB:      hm.GetProcAllocMb(),
			ProcSysMB:        hm.GetProcSysMb(),
			NumCPU:           int(hm.GetNumCpu()),
			NumGoroutine:     int(hm.GetNumGoroutine()),
			InferenceOnline:  hm.GetInferenceOnline(),
			InferenceBaseURL: hm.GetInferenceBaseUrl(),
			InferenceModels:  int(hm.GetInferenceModels()),
			GpuNote:          hm.GetGpuNote(),
		}
	}
	for _, s := range d.GetSteps() {
		if s == nil {
			continue
		}
		snap.Steps = append(snap.Steps, moebiz.PipelineStep{
			Key: s.GetKey(), Label: s.GetLabel(), Status: s.GetStatus(),
			Detail: s.GetDetail(), DurationMS: s.GetDurationMs(),
		})
	}
	return snap
}

func pipelineFromSuper(d *super.AdminGetMoeBrainPipelineResp) moebiz.PipelineSnapshot {
	if d == nil {
		return moebiz.PipelineSnapshot{}
	}
	data := moebridge.PipelineDataFromSuper(d)
	snap := moebiz.PipelineSnapshot{
		AgentKey:        data.AgentKey,
		OK:              data.Ok,
		Detail:          data.Detail,
		PostID:          data.PostId,
		TotalDurationMS: data.TotalDurationMs,
	}
	if data.RunAt != "" {
		if t, err := time.ParseInLocation("2006-01-02 15:04:05", data.RunAt, time.Local); err == nil {
			snap.RunAt = t
			snap.HasRun = true
		}
	}
	snap.Metrics = moebiz.HostMetrics{
		ProcAllocMB: data.HostMetrics.ProcAllocMB, ProcSysMB: data.HostMetrics.ProcSysMB,
		NumCPU: data.HostMetrics.NumCPU, NumGoroutine: data.HostMetrics.NumGoroutine,
		InferenceOnline: data.HostMetrics.InferenceOnline, InferenceBaseURL: data.HostMetrics.InferenceBaseURL,
		InferenceModels: data.HostMetrics.InferenceModels, GpuNote: data.HostMetrics.GpuNote,
	}
	for _, s := range data.Steps {
		snap.Steps = append(snap.Steps, moebiz.PipelineStep{
			Key: s.Key, Label: s.Label, Status: s.Status, Detail: s.Detail, DurationMS: s.DurationMs,
		})
	}
	return snap
}

func brainDataToSnapshot(d types.AdminGetMoeBrainData) *brain.Snapshot {
	s := &brain.Snapshot{
		AgentKey:      d.AgentKey,
		DisplayName:   d.DisplayName,
		ForbiddenTags: d.ForbiddenTags,
		PreferredTags: d.PreferredTags,
	}
	if id, err := moebiz.ParseBotUserID(d.BotUserId); err == nil {
		s.BotUserID = id
	}
	return s
}

func toolStatsToBiz(d types.AdminMoeToolStatsData) moebiz.ToolStatsResult {
	out := moebiz.ToolStatsResult{
		TotalCalls:   d.TotalCalls,
		SuccessCalls: d.SuccessCalls,
		FailedCalls:  d.FailedCalls,
	}
	for _, row := range d.ByTool {
		out.ByTool = append(out.ByTool, toolaudit.ToolStatRow{
			Tool: row.Tool, TotalCalls: row.TotalCalls,
			SuccessCalls: row.SuccessCalls, FailedCalls: row.FailedCalls,
		})
	}
	for _, row := range d.ByDay {
		out.ByDay = append(out.ByDay, toolaudit.DayStatRow{
			Date: row.Date, TotalCalls: row.TotalCalls, SuccessCalls: row.SuccessCalls,
		})
	}
	return out
}

func toolCallsToBiz(d types.AdminListMoeToolCallsData) []moebiz.ToolCallRow {
	out := make([]moebiz.ToolCallRow, 0, len(d.Items))
	for _, row := range d.Items {
		id, _ := strconv.ParseUint(row.Id, 10, 64)
		actor, _ := strconv.ParseUint(row.ActorUserId, 10, 32)
		out = append(out, moebiz.ToolCallRow{
			ID: uint(id), Tool: row.Tool, ActorUserID: uint(actor), AgentKey: row.AgentKey,
			Ok: row.Ok, ErrorMsg: row.ErrorMsg, LatencyMs: row.LatencyMs, Source: row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
		})
	}
	return out
}

func timeFilterStr(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format(time.RFC3339)
}
