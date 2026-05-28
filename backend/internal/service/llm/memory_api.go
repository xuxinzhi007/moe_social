// Package llmapp F109 memory read/embeddings → biz wrappers.
package llmapp

import (
	"context"

	llmv1 "backend/api/llm/v1"
	llmbiz "backend/internal/biz/llm"
)

func (s *AppService) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	out, err := llmbiz.GetUserMemories(ctx, s.memory, llmv1.GetUserMemoriesReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.GetUserMemoriesRespFromMoe(out), nil
}

func (s *AppService) GetUserMemoryProfiles(ctx context.Context, in *llmv1.GetUserMemoryProfilesReq) (*llmv1.GetUserMemoryProfilesResp, error) {
	out, err := llmbiz.GetUserMemoryProfiles(ctx, s.memory, llmv1.GetUserMemoryProfilesReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.GetUserMemoryProfilesRespFromMoe(out), nil
}

func (s *AppService) DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	out, err := llmbiz.DeleteUserMemory(ctx, s.memory, llmv1.DeleteUserMemoryReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.DeleteUserMemoryRespFromMoe(out), nil
}

func (s *AppService) SubmitUserMemoryFeedback(ctx context.Context, in *llmv1.SubmitUserMemoryFeedbackReq) (*llmv1.SubmitUserMemoryFeedbackResp, error) {
	out, err := llmbiz.SubmitUserMemoryFeedback(ctx, s.memory, llmv1.SubmitUserMemoryFeedbackReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.SubmitUserMemoryFeedbackRespFromMoe(out), nil
}

func (s *AppService) RebuildUserMemoryEmbeddings(ctx context.Context, in *llmv1.RebuildUserMemoryEmbeddingsReq) (*llmv1.RebuildUserMemoryEmbeddingsResp, error) {
	out, err := llmbiz.RebuildUserMemoryEmbeddings(ctx, s.memory, llmv1.RebuildUserMemoryEmbeddingsReqToMoe(in), s.deps.Inference.BaseURL)
	if err != nil {
		return nil, err
	}
	return llmv1.RebuildUserMemoryEmbeddingsRespFromMoe(out), nil
}

func (s *AppService) ListUserMemoryEmbeddings(ctx context.Context, in *llmv1.ListUserMemoryEmbeddingsReq) (*llmv1.ListUserMemoryEmbeddingsResp, error) {
	out, err := llmbiz.ListUserMemoryEmbeddings(ctx, s.memory, llmv1.ListUserMemoryEmbeddingsReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.ListUserMemoryEmbeddingsRespFromMoe(out), nil
}

func (s *AppService) ListUserMemoryRelations(ctx context.Context, in *llmv1.ListUserMemoryRelationsReq) (*llmv1.ListUserMemoryRelationsResp, error) {
	out, err := llmbiz.ListUserMemoryRelations(ctx, s.memory, llmv1.ListUserMemoryRelationsReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.ListUserMemoryRelationsRespFromMoe(out), nil
}

func (s *AppService) UpsertUserMemoryEmbedding(ctx context.Context, in *llmv1.UpsertUserMemoryEmbeddingReq) (*llmv1.UpsertUserMemoryEmbeddingResp, error) {
	out, err := llmbiz.UpsertUserMemoryEmbedding(ctx, s.memory, llmv1.UpsertUserMemoryEmbeddingReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.UpsertUserMemoryEmbeddingRespFromMoe(out), nil
}
