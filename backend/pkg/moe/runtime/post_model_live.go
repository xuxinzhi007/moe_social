package runtime

import (
	"context"

	"backend/model"
	"backend/pkg/llminference"
)

// ConfiguredPostModel 配置层期望的发帖模型（不做在线发现）。
func ConfiguredPostModel(deps Deps, rt model.MoeAgentRuntime) string {
	return resolvePostModel(deps, rt)
}

// ResolvePostModelForChat 结合 /v1/models 自动选用实际模型 ID。
func ResolvePostModelForChat(ctx context.Context, deps Deps) (string, llminference.PickResult, error) {
	rt := model.MoeAgentRuntime{}
	preferred := resolvePostModel(deps, rt)
	if !deps.Inference.Ready() {
		return preferred, llminference.PickResult{ModelID: preferred, Preferred: preferred}, nil
	}
	ids, err := llminference.ListModelIDs(ctx, deps.Inference)
	if err != nil {
		return preferred, llminference.PickResult{ModelID: preferred, Preferred: preferred}, err
	}
	pick := llminference.PickModel(preferred, ids)
	return pick.ModelID, pick, nil
}

// ResolvePostModelForRuntime 按 Bot runtime 配置 + 在线模型列表解析。
func ResolvePostModelForRuntime(ctx context.Context, deps Deps, rt model.MoeAgentRuntime) (string, llminference.PickResult, error) {
	preferred := resolvePostModel(deps, rt)
	if !deps.Inference.Ready() {
		return preferred, llminference.PickResult{ModelID: preferred, Preferred: preferred}, nil
	}
	ids, err := llminference.ListModelIDs(ctx, deps.Inference)
	if err != nil {
		return preferred, llminference.PickResult{ModelID: preferred, Preferred: preferred}, err
	}
	pick := llminference.PickModel(preferred, ids)
	return pick.ModelID, pick, nil
}
