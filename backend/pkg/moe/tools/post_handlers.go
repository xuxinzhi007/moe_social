package tools

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/core"
	"backend/pkg/moe/postpulse"

	postv1 "backend/api/post/v1"

	"gorm.io/gorm"
)

type postSearchArgs struct {
	Query   string `json:"query"`
	Limit   int    `json:"limit"`
	MoodTag string `json:"mood_tag"`
}

type postGetArgs struct {
	PostID string `json:"post_id"`
}

type postCreateArgs struct {
	Content string `json:"content"`
	MoodTag string `json:"mood_tag"`
}

func (e *Executor) execPostSearch(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	var args postSearchArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	if e.deps.DB == nil {
		return fail("数据库未就绪")
	}
	hits, err := postpulse.KeywordSearch(ctx, e.deps.DB, postpulse.SearchOptions{
		Query:     args.Query,
		Limit:     args.Limit,
		ViewerUID: req.ActorUserID,
		MoodTag:   args.MoodTag,
		Explain:   true,
	})
	if err != nil {
		return fail("检索失败")
	}
	return ok(map[string]any{"items": hits, "total": len(hits)})
}

func (e *Executor) execPostGet(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	var args postGetArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	resp, err := e.deps.RPC.GetPost(ctx, &postv1.GetPostRequest{
		PostId: args.PostID,
	})
	if err != nil || resp == nil || resp.Post == nil {
		return fail("帖子不存在")
	}
	p := resp.Post
	return ok(map[string]any{
		"post_id":    p.Id,
		"user_id":    p.UserId,
		"user_name":  p.UserName,
		"content":    p.Content,
		"likes":      p.Likes,
		"comments":   p.Comments,
		"created_at": p.CreatedAt,
	})
}

func (e *Executor) execPostCreate(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	botUID := req.BotUserID
	if botUID == 0 {
		botUID = req.ActorUserID
	}
	if botUID == 0 {
		return fail("需要 bot_user_id")
	}
	var args postCreateArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	content := strings.TrimSpace(args.Content)
	if content == "" {
		return fail("content 不能为空")
	}
	if len([]rune(content)) > 500 {
		return fail("内容过长（上限 500 字）")
	}

	if e.deps.DB != nil {
		var user model.User
		if err := e.deps.DB.Where("id = ? AND is_bot = ?", botUID, true).First(&user).Error; err != nil {
			return fail("仅 Bot 账号可调用 post_create")
		}
		if req.AgentKey != "" {
			if err := bumpPostQuota(e.deps.DB, req.AgentKey); err != nil {
				return fail(err.Error())
			}
		}
	}

	uid := strconv.FormatUint(uint64(botUID), 10)
	createResp, err := e.deps.RPC.CreatePost(ctx, &postv1.CreatePostRequest{
		UserId:  uid,
		Content: content,
		MoodTag: strings.TrimSpace(args.MoodTag),
	})
	if err != nil || createResp == nil || createResp.Post == nil {
		return fail("发帖失败")
	}
	postID := createResp.Post.Id
	if e.deps.DB != nil && req.AgentKey != "" {
		now := time.Now()
		_ = e.deps.DB.Model(&model.MoeAgentRuntime{}).
			Where("agent_key = ?", req.AgentKey).
			Updates(map[string]any{
				"last_run_at":  now,
				"last_post_id": postID,
			}).Error
	}
	return ok(map[string]any{"post_id": postID, "created": true})
}

func bumpPostQuota(db *gorm.DB, agentKey string) error {
	var rt model.MoeAgentRuntime
	if err := db.Where("agent_key = ? AND enabled = ?", agentKey, true).First(&rt).Error; err != nil {
		return nil
	}
	today := time.Now().Truncate(24 * time.Hour)
	if rt.QuotaResetDate == nil || !rt.QuotaResetDate.Equal(today) {
		_ = db.Model(&rt).Updates(map[string]any{
			"posts_today":      0,
			"quota_reset_date": today,
		}).Error
		rt.PostsToday = 0
	}
	if rt.PostQuotaDaily > 0 && rt.PostsToday >= rt.PostQuotaDaily {
		return errQuotaExceeded
	}
	return db.Model(&rt).UpdateColumn("posts_today", gorm.Expr("posts_today + 1")).Error
}

var errQuotaExceeded = &quotaError{}

type quotaError struct{}

func (e *quotaError) Error() string { return "已达今日发帖配额" }
