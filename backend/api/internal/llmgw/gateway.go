package llmgw

import (
	"context"

	llmapp "backend/internal/service/llm"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway LLM HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *llmapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *llmapp.AppService, legacy super.SuperClient) *Gateway {
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

func (g *Gateway) RecordLlmChatTurn(ctx context.Context, in *super.RecordLlmChatTurnReq, opts ...grpc.CallOption) (*super.RecordLlmChatTurnResp, error) {
	if g != nil && g.local != nil {
		return g.local.RecordLlmChatTurn(ctx, in)
	}
	if g == nil || g.super == nil {
		return &super.RecordLlmChatTurnResp{Ok: false}, nil
	}
	return g.super.RecordLlmChatTurn(ctx, in, opts...)
}

func (g *Gateway) GetAiUserConfig(ctx context.Context, in *super.GetAiUserConfigReq, opts ...grpc.CallOption) (*super.GetAiUserConfigResp, error) {
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetAiUserConfig(ctx, in, opts...)
}

func (g *Gateway) GetUserMemories(ctx context.Context, in *super.GetUserMemoriesReq, opts ...grpc.CallOption) (*super.GetUserMemoriesResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserMemories(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserMemories(ctx, in, opts...)
}

func (g *Gateway) GetUserMemoryProfiles(ctx context.Context, in *super.GetUserMemoryProfilesReq, opts ...grpc.CallOption) (*super.GetUserMemoryProfilesResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserMemoryProfiles(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserMemoryProfiles(ctx, in, opts...)
}

func (g *Gateway) DeleteUserMemory(ctx context.Context, in *super.DeleteUserMemoryReq, opts ...grpc.CallOption) (*super.DeleteUserMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteUserMemory(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.DeleteUserMemory(ctx, in, opts...)
}

func (g *Gateway) SubmitUserMemoryFeedback(ctx context.Context, in *super.SubmitUserMemoryFeedbackReq, opts ...grpc.CallOption) (*super.SubmitUserMemoryFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.SubmitUserMemoryFeedback(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.SubmitUserMemoryFeedback(ctx, in, opts...)
}

func (g *Gateway) RebuildUserMemoryEmbeddings(ctx context.Context, in *super.RebuildUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*super.RebuildUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.RebuildUserMemoryEmbeddings(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.RebuildUserMemoryEmbeddings(ctx, in, opts...)
}

func (g *Gateway) ListUserMemoryEmbeddings(ctx context.Context, in *super.ListUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*super.ListUserMemoryEmbeddingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserMemoryEmbeddings(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.ListUserMemoryEmbeddings(ctx, in, opts...)
}

func (g *Gateway) ListUserMemoryRelations(ctx context.Context, in *super.ListUserMemoryRelationsReq, opts ...grpc.CallOption) (*super.ListUserMemoryRelationsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserMemoryRelations(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.ListUserMemoryRelations(ctx, in, opts...)
}

func (g *Gateway) UpsertUserMemory(ctx context.Context, in *super.UpsertUserMemoryReq, opts ...grpc.CallOption) (*super.UpsertUserMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertUserMemory(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.UpsertUserMemory(ctx, in, opts...)
}
