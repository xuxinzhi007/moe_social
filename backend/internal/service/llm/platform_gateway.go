package llmapp

import (
	"context"

	llmv1 "backend/api/llm/v1"
	llmbiz "backend/internal/biz/llm"
	userbiz "backend/internal/biz/user"

	"google.golang.org/grpc"
)

type platformChatGateway struct {
	app *AppService
}

// PlatformChatGateway returns an in-process llmv1 gateway backed by this AppService.
func (s *AppService) PlatformChatGateway() llmbiz.PlatformChatGateway {
	if s == nil {
		return nil
	}
	return &platformChatGateway{app: s}
}

func (g *platformChatGateway) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	return g.app.GetUserMemories(ctx, in)
}

func (g *platformChatGateway) GetUserMemoryProfiles(ctx context.Context, in *llmv1.GetUserMemoryProfilesReq) (*llmv1.GetUserMemoryProfilesResp, error) {
	return g.app.GetUserMemoryProfiles(ctx, in)
}

func (g *platformChatGateway) UpsertUserMemory(ctx context.Context, in *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error) {
	return g.app.UpsertUserMemory(ctx, in)
}

func (g *platformChatGateway) GetAiUserConfig(ctx context.Context, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	return g.app.GetAiUserConfig(ctx, in)
}

func (g *platformChatGateway) RecordLlmChatTurn(ctx context.Context, in *llmv1.RecordLlmChatTurnReq) (*llmv1.RecordLlmChatTurnResp, error) {
	return g.app.RecordLlmChatTurn(ctx, in)
}

type memoryGateway struct {
	app *AppService
}

// MemoryGateway returns an in-process userbiz.LLMMemoryGateway backed by this AppService.
func (s *AppService) MemoryGateway() userbiz.LLMMemoryGateway {
	if s == nil {
		return nil
	}
	return &memoryGateway{app: s}
}

func (g *memoryGateway) ListUserMemoryEmbeddings(
	ctx context.Context,
	in *llmv1.ListUserMemoryEmbeddingsReq,
	_ ...grpc.CallOption,
) (*llmv1.ListUserMemoryEmbeddingsResp, error) {
	return g.app.ListUserMemoryEmbeddings(ctx, in)
}

func (g *memoryGateway) RebuildUserMemoryEmbeddings(
	ctx context.Context,
	in *llmv1.RebuildUserMemoryEmbeddingsReq,
	_ ...grpc.CallOption,
) (*llmv1.RebuildUserMemoryEmbeddingsResp, error) {
	return g.app.RebuildUserMemoryEmbeddings(ctx, in)
}

func (g *memoryGateway) ListUserMemoryRelations(
	ctx context.Context,
	in *llmv1.ListUserMemoryRelationsReq,
	_ ...grpc.CallOption,
) (*llmv1.ListUserMemoryRelationsResp, error) {
	return g.app.ListUserMemoryRelations(ctx, in)
}
