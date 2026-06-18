// Package llmapp F109 memory read/embeddings → biz wrappers.
package llmapp

import (
	"context"
	llmv1 "backend/api/llm/v1"
	llmbiz "backend/internal/biz/llm"
)

// Package llmapp F109 memory read/embeddings → biz wrappers.

func (s *AppService) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	return llmbiz.GetUserMemories(ctx, s.memory, in)
}

func (s *AppService) GetUserMemoryProfiles(ctx context.Context, in *llmv1.GetUserMemoryProfilesReq) (*llmv1.GetUserMemoryProfilesResp, error) {
	return llmbiz.GetUserMemoryProfiles(ctx, s.memory, in)
}

func (s *AppService) DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	return llmbiz.DeleteUserMemory(ctx, s.memory, in)
}

func (s *AppService) SubmitUserMemoryFeedback(ctx context.Context, in *llmv1.SubmitUserMemoryFeedbackReq) (*llmv1.SubmitUserMemoryFeedbackResp, error) {
	return llmbiz.SubmitUserMemoryFeedback(ctx, s.memory, in)
}

func (s *AppService) RebuildUserMemoryEmbeddings(ctx context.Context, in *llmv1.RebuildUserMemoryEmbeddingsReq) (*llmv1.RebuildUserMemoryEmbeddingsResp, error) {
	return llmbiz.RebuildUserMemoryEmbeddings(ctx, s.memory, in, s.deps.Inference.BaseURL)
}

func (s *AppService) ListUserMemoryEmbeddings(ctx context.Context, in *llmv1.ListUserMemoryEmbeddingsReq) (*llmv1.ListUserMemoryEmbeddingsResp, error) {
	return llmbiz.ListUserMemoryEmbeddings(ctx, s.memory, in)
}

func (s *AppService) ListUserMemoryRelations(ctx context.Context, in *llmv1.ListUserMemoryRelationsReq) (*llmv1.ListUserMemoryRelationsResp, error) {
	return llmbiz.ListUserMemoryRelations(ctx, s.memory, in)
}

func (s *AppService) UpsertUserMemoryEmbedding(ctx context.Context, in *llmv1.UpsertUserMemoryEmbeddingReq) (*llmv1.UpsertUserMemoryEmbeddingResp, error) {
	return llmbiz.UpsertUserMemoryEmbedding(ctx, s.memory, in)
}
