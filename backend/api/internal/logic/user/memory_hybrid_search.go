package user

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/api/internal/svc"
	"backend/rpc/pb/moe"
)

// HybridSearchUserFacingMemories Phase 2+3：混合检索 → 图谱扩展 → rerank。
func HybridSearchUserFacingMemories(
	ctx context.Context,
	svcCtx *svc.ServiceContext,
	userID string,
	memories []*moe.UserMemory,
	query string,
	limit int,
) SearchUserMemoriesResult {
	inferenceBaseURL := ""
	var gw userbiz.LLMMemoryGateway
	if svcCtx != nil {
		inferenceBaseURL = svcCtx.Config.LLMInference.BaseUrl
		gw = svcCtx.LLMGW
	}
	return userbiz.HybridSearchUserFacingMemories(ctx, userbiz.MemorySearchParams{
		Gateway:          gw,
		InferenceBaseURL: inferenceBaseURL,
		UserID:           userID,
		Memories:         memories,
		Query:            query,
		Limit:            limit,
	})
}
