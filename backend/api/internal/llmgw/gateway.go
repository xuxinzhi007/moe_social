package llmgw

import (
	"context"

	llmapp "backend/internal/service/llm"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway LLM HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *llmapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *llmapp.AppService, legacy moe.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) RecordLlmChatTurn(ctx context.Context, in *moe.RecordLlmChatTurnReq, opts ...grpc.CallOption) (*moe.RecordLlmChatTurnResp, error) {
	if g != nil && g.local != nil {
		return g.local.RecordLlmChatTurn(ctx, in)
	}
	if g == nil || g.super == nil {
		return &moe.RecordLlmChatTurnResp{Ok: false}, nil
	}
	return g.super.RecordLlmChatTurn(ctx, in, opts...)
}

func (g *Gateway) GetAiUserConfig(ctx context.Context, in *moe.GetAiUserConfigReq, opts ...grpc.CallOption) (*moe.GetAiUserConfigResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetAiUserConfig(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetAiUserConfig(ctx, in, opts...)
}

func (g *Gateway) UpsertAiUserConfig(ctx context.Context, in *moe.UpsertAiUserConfigReq, opts ...grpc.CallOption) (*moe.UpsertAiUserConfigResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertAiUserConfig(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.UpsertAiUserConfig(ctx, in, opts...)
}

func (g *Gateway) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq, opts ...grpc.CallOption) (*moe.GetUserMemoriesResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserMemories(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserMemories(ctx, in, opts...)
}

func (g *Gateway) GetUserMemoryProfiles(ctx context.Context, in *moe.GetUserMemoryProfilesReq, opts ...grpc.CallOption) (*moe.GetUserMemoryProfilesResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserMemoryProfiles(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserMemoryProfiles(ctx, in, opts...)
}

func (g *Gateway) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq, opts ...grpc.CallOption) (*moe.DeleteUserMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteUserMemory(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.DeleteUserMemory(ctx, in, opts...)
}

func (g *Gateway) SubmitUserMemoryFeedback(ctx context.Context, in *moe.SubmitUserMemoryFeedbackReq, opts ...grpc.CallOption) (*moe.SubmitUserMemoryFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.SubmitUserMemoryFeedback(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.SubmitUserMemoryFeedback(ctx, in, opts...)
}

func (g *Gateway) RebuildUserMemoryEmbeddings(ctx context.Context, in *moe.RebuildUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.RebuildUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.RebuildUserMemoryEmbeddings(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.RebuildUserMemoryEmbeddings(ctx, in, opts...)
}

func (g *Gateway) ListUserMemoryEmbeddings(ctx context.Context, in *moe.ListUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserMemoryEmbeddings(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.ListUserMemoryEmbeddings(ctx, in, opts...)
}

func (g *Gateway) ListUserMemoryRelations(ctx context.Context, in *moe.ListUserMemoryRelationsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryRelationsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserMemoryRelations(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.ListUserMemoryRelations(ctx, in, opts...)
}

func (g *Gateway) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq, opts ...grpc.CallOption) (*moe.UpsertUserMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertUserMemory(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.UpsertUserMemory(ctx, in, opts...)
}
