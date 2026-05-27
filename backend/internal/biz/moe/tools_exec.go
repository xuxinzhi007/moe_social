package moebiz

import (
	"context"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/core"
	"backend/pkg/moe/postpulse"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"

	"gorm.io/gorm"
)

// ExecuteToolInput 执行 Moe 工具请求。
type ExecuteToolInput struct {
	Tool           string
	ArgumentsJSON  string
	ActorUserID    uint
	AgentKey       string
	Source         string
	IdempotencyKey string
}

// ExecuteToolResult 执行结果。
type ExecuteToolResult struct {
	OK     bool
	Result string
	Error  string
}

// SearchPostsInput 社区帖子检索。
type SearchPostsInput struct {
	Query        string
	ViewerUserID uint
	MoodTag      string
	TopicTagID   uint
	Limit        int
}

// ExecuteTool 执行工具并写入审计日志。
func ExecuteTool(ctx context.Context, db *gorm.DB, deps tools.Deps, in ExecuteToolInput) ExecuteToolResult {
	tier := core.DefaultTier
	botUID := uint(0)
	agentKey := strings.TrimSpace(in.AgentKey)
	if agentKey != "" && db != nil {
		var rt model.MoeAgentRuntime
		if err := db.Where("agent_key = ?", agentKey).First(&rt).Error; err == nil {
			tier = core.ParseTier(rt.CapabilityTier)
			botUID = rt.BotUserID
		}
	}
	source := strings.TrimSpace(in.Source)
	if source == "" {
		source = "api"
	}
	start := time.Now()
	exec := tools.NewExecutor(deps)
	res := exec.Execute(ctx, core.ExecuteRequest{
		Tool:           in.Tool,
		ArgumentsJSON:  in.ArgumentsJSON,
		ActorUserID:    in.ActorUserID,
		BotUserID:      botUID,
		AgentKey:       agentKey,
		Tier:           tier,
		IdempotencyKey: in.IdempotencyKey,
	})
	latency := int(time.Since(start).Milliseconds())
	toolaudit.Record(db, toolaudit.RecordInput{
		Tool:           in.Tool,
		ArgumentsJSON:  in.ArgumentsJSON,
		ActorUserID:    in.ActorUserID,
		BotUserID:      botUID,
		AgentKey:       agentKey,
		Ok:             res.OK,
		ErrorMsg:       res.Error,
		LatencyMs:      latency,
		Source:         source,
		IdempotencyKey: in.IdempotencyKey,
	})
	return ExecuteToolResult{OK: res.OK, Result: res.Result, Error: res.Error}
}

// SearchPosts 关键词检索社区帖子。
func SearchPosts(ctx context.Context, db *gorm.DB, in SearchPostsInput) ([]postpulse.SearchHit, error) {
	limit := in.Limit
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}
	return postpulse.KeywordSearch(ctx, db, postpulse.SearchOptions{
		Query:      in.Query,
		Limit:      limit,
		ViewerUID:  in.ViewerUserID,
		MoodTag:    in.MoodTag,
		TopicTagID: in.TopicTagID,
		Explain:    true,
	})
}
