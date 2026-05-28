// Package llmapp F109 memory read/embeddings → biz wrappers.
package llmapp

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/rpc/pb/super"
)

func (s *AppService) GetUserMemories(ctx context.Context, in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	return llmbiz.GetUserMemories(ctx, s.db, in)
}

func (s *AppService) GetUserMemoryProfiles(ctx context.Context, in *super.GetUserMemoryProfilesReq) (*super.GetUserMemoryProfilesResp, error) {
	return llmbiz.GetUserMemoryProfiles(ctx, s.db, in)
}

func (s *AppService) DeleteUserMemory(ctx context.Context, in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	return llmbiz.DeleteUserMemory(ctx, s.db, in)
}

func (s *AppService) SubmitUserMemoryFeedback(ctx context.Context, in *super.SubmitUserMemoryFeedbackReq) (*super.SubmitUserMemoryFeedbackResp, error) {
	return llmbiz.SubmitUserMemoryFeedback(ctx, s.db, in)
}

func (s *AppService) RebuildUserMemoryEmbeddings(ctx context.Context, in *super.RebuildUserMemoryEmbeddingsReq) (*super.RebuildUserMemoryEmbeddingsResp, error) {
	return llmbiz.RebuildUserMemoryEmbeddings(ctx, s.db, in, s.deps.Inference.BaseURL)
}

func (s *AppService) ListUserMemoryEmbeddings(ctx context.Context, in *super.ListUserMemoryEmbeddingsReq) (*super.ListUserMemoryEmbeddingsResp, error) {
	return llmbiz.ListUserMemoryEmbeddings(ctx, s.db, in)
}

func (s *AppService) ListUserMemoryRelations(ctx context.Context, in *super.ListUserMemoryRelationsReq) (*super.ListUserMemoryRelationsResp, error) {
	return llmbiz.ListUserMemoryRelations(ctx, s.db, in)
}

func (s *AppService) UpsertUserMemoryEmbedding(ctx context.Context, in *super.UpsertUserMemoryEmbeddingReq) (*super.UpsertUserMemoryEmbeddingResp, error) {
	return llmbiz.UpsertUserMemoryEmbedding(ctx, s.db, in)
}
