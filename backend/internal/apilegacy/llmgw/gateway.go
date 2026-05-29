package llmgw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	llmv1 "backend/api/llm/v1"
	llmapp "backend/internal/service/llm"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway LLM HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *llmapp.AppService
}

// New 构造网关。
func New(local *llmapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) RecordLlmChatTurn(ctx context.Context, in *moe.RecordLlmChatTurnReq, opts ...grpc.CallOption) (*moe.RecordLlmChatTurnResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.RecordLlmChatTurn(ctx, llmv1.RecordLlmChatTurnReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.RecordLlmChatTurnRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetAiUserConfig(ctx context.Context, in *moe.GetAiUserConfigReq, opts ...grpc.CallOption) (*moe.GetAiUserConfigResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetAiUserConfig(ctx, llmv1.GetAiUserConfigReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.GetAiUserConfigRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpsertAiUserConfig(ctx context.Context, in *moe.UpsertAiUserConfigReq, opts ...grpc.CallOption) (*moe.UpsertAiUserConfigResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertAiUserConfig(ctx, llmv1.UpsertAiUserConfigReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.UpsertAiUserConfigRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq, opts ...grpc.CallOption) (*moe.GetUserMemoriesResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserMemories(ctx, llmv1.GetUserMemoriesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.GetUserMemoriesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserMemoryProfiles(ctx context.Context, in *moe.GetUserMemoryProfilesReq, opts ...grpc.CallOption) (*moe.GetUserMemoryProfilesResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserMemoryProfiles(ctx, llmv1.GetUserMemoryProfilesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.GetUserMemoryProfilesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq, opts ...grpc.CallOption) (*moe.DeleteUserMemoryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteUserMemory(ctx, llmv1.DeleteUserMemoryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.DeleteUserMemoryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SubmitUserMemoryFeedback(ctx context.Context, in *moe.SubmitUserMemoryFeedbackReq, opts ...grpc.CallOption) (*moe.SubmitUserMemoryFeedbackResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SubmitUserMemoryFeedback(ctx, llmv1.SubmitUserMemoryFeedbackReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.SubmitUserMemoryFeedbackRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) RebuildUserMemoryEmbeddings(ctx context.Context, in *moe.RebuildUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.RebuildUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.RebuildUserMemoryEmbeddings(ctx, llmv1.RebuildUserMemoryEmbeddingsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.RebuildUserMemoryEmbeddingsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListUserMemoryEmbeddings(ctx context.Context, in *moe.ListUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListUserMemoryEmbeddings(ctx, llmv1.ListUserMemoryEmbeddingsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.ListUserMemoryEmbeddingsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListUserMemoryRelations(ctx context.Context, in *moe.ListUserMemoryRelationsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryRelationsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListUserMemoryRelations(ctx, llmv1.ListUserMemoryRelationsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.ListUserMemoryRelationsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq, opts ...grpc.CallOption) (*moe.UpsertUserMemoryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertUserMemory(ctx, llmv1.UpsertUserMemoryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return llmv1.UpsertUserMemoryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
