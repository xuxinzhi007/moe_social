package logic

import (
	"context"
	"strings"

	"backend/pkg/moe/runtime"
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

func defaultPipelineSteps() []*super.MoePipelineStepItem {
	return []*super.MoePipelineStepItem{
		{Key: "load_runtime", Label: "加载 Bot 配置", Status: "skip", Detail: "尚无试跑记录"},
		{Key: "gather_memory", Label: "检索记忆与社区脉搏", Status: "skip"},
		{Key: "generate", Label: "LLM 生成正文", Status: "skip"},
		{Key: "post_create", Label: "发布动态", Status: "skip"},
		{Key: "record_episode", Label: "写入自传", Status: "skip"},
	}
}

func (l *AdminGetMoeBrainPipelineLogic) AdminGetMoeBrainPipeline(in *super.AdminGetMoeBrainPipelineReq) (*super.AdminGetMoeBrainPipelineResp, error) {
	agentKey := strings.TrimSpace(in.GetAgentKey())
	out := &super.AdminGetMoeBrainPipelineResp{
		AgentKey: agentKey,
		Steps:    defaultPipelineSteps(),
	}
	if agentKey == "" || l.svcCtx.DB == nil {
		return out, nil
	}
	row, err := runtime.LatestAgentRunLog(l.svcCtx.DB, agentKey)
	if err != nil || row == nil {
		return out, nil
	}
	bundle := runtime.ParseRunLog(row.StepsJSON)
	out.Ok = row.OK
	out.Detail = row.Detail
	out.PostId = row.PostID
	out.RunAt = row.CreatedAt.Format("2006-01-02 15:04:05")
	out.TotalDurationMs = bundle.TotalMs
	out.HostMetrics = hostMetricsProto(bundle.Metrics)
	if len(bundle.Steps) == 0 {
		return out, nil
	}
	out.Steps = make([]*super.MoePipelineStepItem, 0, len(bundle.Steps))
	for _, s := range bundle.Steps {
		out.Steps = append(out.Steps, &super.MoePipelineStepItem{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMs: s.MS,
		})
	}
	return out, nil
}

func hostMetricsProto(m runtime.HostMetrics) *super.MoeHostMetrics {
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
