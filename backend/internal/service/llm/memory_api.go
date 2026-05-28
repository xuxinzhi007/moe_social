// Package llmapp F109 memory read/embeddings → biz wrappers.
package llmapp

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/rpc/pb/moe"
)

func (s *AppService) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return llmbiz.GetUserMemories(ctx, s.db, in)
}

func (s *AppService) GetUserMemoryProfiles(ctx context.Context, in *moe.GetUserMemoryProfilesReq) (*moe.GetUserMemoryProfilesResp, error) {
	return llmbiz.GetUserMemoryProfiles(ctx, s.db, in)
}

func (s *AppService) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return llmbiz.DeleteUserMemory(ctx, s.db, in)
}

func (s *AppService) SubmitUserMemoryFeedback(ctx context.Context, in *moe.SubmitUserMemoryFeedbackReq) (*moe.SubmitUserMemoryFeedbackResp, error) {
	return llmbiz.SubmitUserMemoryFeedback(ctx, s.db, in)
}

func (s *AppService) RebuildUserMemoryEmbeddings(ctx context.Context, in *moe.RebuildUserMemoryEmbeddingsReq) (*moe.RebuildUserMemoryEmbeddingsResp, error) {
	return llmbiz.RebuildUserMemoryEmbeddings(ctx, s.db, in, s.deps.Inference.BaseURL)
}

func (s *AppService) ListUserMemoryEmbeddings(ctx context.Context, in *moe.ListUserMemoryEmbeddingsReq) (*moe.ListUserMemoryEmbeddingsResp, error) {
	return llmbiz.ListUserMemoryEmbeddings(ctx, s.db, in)
}

func (s *AppService) ListUserMemoryRelations(ctx context.Context, in *moe.ListUserMemoryRelationsReq) (*moe.ListUserMemoryRelationsResp, error) {
	return llmbiz.ListUserMemoryRelations(ctx, s.db, in)
}

func (s *AppService) UpsertUserMemoryEmbedding(ctx context.Context, in *moe.UpsertUserMemoryEmbeddingReq) (*moe.UpsertUserMemoryEmbeddingResp, error) {
	return llmbiz.UpsertUserMemoryEmbedding(ctx, s.db, in)
}
