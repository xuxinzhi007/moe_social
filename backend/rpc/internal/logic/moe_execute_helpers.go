package logic

import (
	"context"

	"backend/pkg/moe/core"
	"backend/pkg/moe/postpulse"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

func coreDefaultTier() core.CapabilityTier {
	return core.DefaultTier
}

func parseCapabilityTier(raw string) core.CapabilityTier {
	return core.ParseTier(raw)
}

func coreExecuteRequest(in *super.MoeExecuteToolReq, tier core.CapabilityTier, botUID uint) core.ExecuteRequest {
	return core.ExecuteRequest{
		Tool:           in.Tool,
		ArgumentsJSON:  in.ArgumentsJson,
		ActorUserID:    uint(in.ActorUserId),
		BotUserID:      botUID,
		AgentKey:       in.AgentKey,
		Tier:           tier,
		IdempotencyKey: in.IdempotencyKey,
	}
}

func postpulseKeywordSearch(ctx context.Context, db *gorm.DB, in *super.MoeSearchPostsReq, limit int) ([]postpulse.SearchHit, error) {
	return postpulse.KeywordSearch(ctx, db, postpulse.SearchOptions{
		Query:      in.Query,
		Limit:      limit,
		ViewerUID:  uint(in.ViewerUserId),
		MoodTag:    in.MoodTag,
		TopicTagID: uint(in.TopicTagId),
		Explain:    true,
	})
}
