package moebridge

import (
	"fmt"

	"backend/api/internal/svc"
	"backend/pkg/llminference"
	"backend/pkg/moe/port"
	"backend/pkg/moe/tools"
)

// ToolDeps 已废弃：工具执行改走 RPC MoeExecuteTool。保留 GRPC 适配供测试/过渡。
func ToolDeps(svcCtx *svc.ServiceContext) (tools.Deps, error) {
	if svcCtx == nil {
		return tools.Deps{}, fmt.Errorf("service context 为空")
	}
	return tools.Deps{
		RPC: port.GRPCAdapter{Client: svcCtx.SuperRpcClient},
		Inference: llminference.ConfigFrom(
			svcCtx.Config.Ollama.BaseUrl,
			svcCtx.Config.Ollama.ApiStyle,
			int(svcCtx.Config.Ollama.TimeoutSeconds),
			svcCtx.Config.Ollama.MemoryModel,
		),
	}, nil
}
