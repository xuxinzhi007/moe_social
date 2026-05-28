package logic

import (
	"context"

	moebiz "backend/internal/biz/moe"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBrainPipelineLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMoeBrainPipelineLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainPipelineLogic {
	return &AdminGetMoeBrainPipelineLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminGetMoeBrainPipelineLogic) AdminGetMoeBrainPipeline(in *super.AdminGetMoeBrainPipelineReq) (*super.AdminGetMoeBrainPipelineResp, error) {
	snap, err := l.svcCtx.MoeAdmin.GetBrainPipeline(l.ctx, in.GetAgentKey())
	if err != nil {
		return nil, err
	}
	return pipelineSnapshotToProto(snap), nil
}

func pipelineSnapshotToProto(snap moebiz.PipelineSnapshot) *super.AdminGetMoeBrainPipelineResp {
	out := &super.AdminGetMoeBrainPipelineResp{
		AgentKey: snap.AgentKey,
		Ok:       snap.OK,
		Detail:   snap.Detail,
		PostId:   snap.PostID,
	}
	if snap.HasRun {
		out.RunAt = snap.RunAt.Format("2006-01-02 15:04:05")
		out.TotalDurationMs = snap.TotalDurationMS
		out.HostMetrics = hostMetricsProtoFromBiz(snap.Metrics)
	}
	out.GenerateAttempts = make([]*super.MoeGenAttemptItem, 0, len(snap.GenerateAttempts))
	for _, a := range snap.GenerateAttempts {
		out.GenerateAttempts = append(out.GenerateAttempts, &super.MoeGenAttemptItem{
			Attempt: int32(a.Attempt),
			Outcome: a.Outcome,
			Snippet: a.Snippet,
			Note:    a.Note,
		})
	}
	out.Steps = make([]*super.MoePipelineStepItem, 0, len(snap.Steps))
	for _, s := range snap.Steps {
		out.Steps = append(out.Steps, &super.MoePipelineStepItem{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMs: s.DurationMS,
		})
	}
	out.StabilityScore = int32(snap.StabilityScore)
	out.StabilityDelta = int32(snap.StabilityDelta)
	out.RunFeedback = snap.RunFeedback
	return out
}

func hostMetricsProtoFromBiz(m moebiz.HostMetrics) *super.MoeHostMetrics {
	if m.NumCPU == 0 && m.ProcAllocMB == 0 && !m.InferenceOnline && m.GpuNote == "" {
		return nil
	}
	return &super.MoeHostMetrics{
		ProcAllocMb:      m.ProcAllocMB,
		ProcSysMb:        m.ProcSysMB,
		NumCpu:           int32(m.NumCPU),
		NumGoroutine:     int32(m.NumGoroutine),
		InferenceOnline:  m.InferenceOnline,
		InferenceBaseUrl: m.InferenceBaseURL,
		InferenceModels:  int32(m.InferenceModels),
		GpuNote:          m.GpuNote,
	}
}
