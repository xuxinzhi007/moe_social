package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBrainPipelineLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeBrainPipelineLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainPipelineLogic {
	return &AdminGetMoeBrainPipelineLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetMoeBrainPipelineLogic) AdminGetMoeBrainPipeline(req *types.AdminGetMoeBrainPipelineReq) (*types.AdminGetMoeBrainPipelineResp, error) {
	if l.svcCtx.SuperRpcClient == nil {
		return &types.AdminGetMoeBrainPipelineResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminGetMoeBrainPipelineData{AgentKey: req.AgentKey, Steps: defaultPipelineStepTypes()},
		}, nil
	}
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminGetMoeBrainPipeline(l.ctx, &super.AdminGetMoeBrainPipelineReq{
		AgentKey: req.AgentKey,
	})
	if err != nil {
		return &types.AdminGetMoeBrainPipelineResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	data := types.AdminGetMoeBrainPipelineData{
		AgentKey:        rpcResp.GetAgentKey(),
		Ok:              rpcResp.GetOk(),
		Detail:          rpcResp.GetDetail(),
		PostId:          rpcResp.GetPostId(),
		RunAt:           rpcResp.GetRunAt(),
		TotalDurationMs: rpcResp.GetTotalDurationMs(),
		Steps:           make([]types.MoePipelineStepItem, 0, len(rpcResp.GetSteps())),
	}
	if hm := rpcResp.GetHostMetrics(); hm != nil {
		data.HostMetrics = types.MoeHostMetrics{
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
	for _, s := range rpcResp.GetSteps() {
		if s == nil {
			continue
		}
		data.Steps = append(data.Steps, types.MoePipelineStepItem{
			Key:        s.GetKey(),
			Label:      s.GetLabel(),
			Status:     s.GetStatus(),
			Detail:     s.GetDetail(),
			DurationMs: s.GetDurationMs(),
		})
	}
	if len(data.Steps) == 0 {
		data.Steps = defaultPipelineStepTypes()
	}
	return &types.AdminGetMoeBrainPipelineResp{
		BaseResp: common.HandleError(nil),
		Data:     data,
	}, nil
}

func defaultPipelineStepTypes() []types.MoePipelineStepItem {
	return []types.MoePipelineStepItem{
		{Key: "load_runtime", Label: "加载 Bot 配置", Status: "skip", Detail: "尚无试跑记录"},
		{Key: "gather_memory", Label: "检索记忆与社区脉搏", Status: "skip"},
		{Key: "generate", Label: "LLM 生成正文", Status: "skip"},
		{Key: "post_create", Label: "发布动态", Status: "skip"},
		{Key: "record_episode", Label: "写入自传", Status: "skip"},
	}
}
