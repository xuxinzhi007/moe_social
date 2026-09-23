package tools

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
	"backend/pkg/moe/core"
	"backend/pkg/moe/postpulse"

	postv1 "backend/api/post/v1"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
	}
	releaseQuota := func() error { return nil }
	if e.deps.DB != nil && req.AgentKey != "" {
		var err error
		releaseQuota, err = reservePostQuota(e.deps.DB, req.AgentKey)
		if err != nil {
			if errors.Is(err, errQuotaExceeded) {
				return fail(err.Error())
			}
			moelog.Errorf("moe post quota reservation failed agent=%s: %v", req.AgentKey, err)
			return fail("发帖额度预留失败")
		}
	}

	uid := strconv.FormatUint(uint64(botUID), 10)
	createResp, err := e.deps.RPC.CreatePost(ctx, &postv1.CreatePostRequest{
		UserId:  uid,
		Content: content,
		MoodTag: strings.TrimSpace(args.MoodTag),
	})
	if err != nil || createResp == nil || createResp.Post == nil {
		if releaseErr := releaseQuota(); releaseErr != nil {
			moelog.Errorf("moe post quota rollback failed agent=%s: %v", req.AgentKey, releaseErr)
		}
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

func reservePostQuota(db *gorm.DB, agentKey string) (func() error, error) {
	noReservation := func() error { return nil }
	if db == nil || strings.TrimSpace(agentKey) == "" {
		return noReservation, nil
	}

	today := time.Now().UTC().Truncate(24 * time.Hour)
	reserved := false
	err := db.Transaction(func(tx *gorm.DB) error {
		var rt model.MoeAgentRuntime
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("agent_key = ? AND enabled = ?", agentKey, true).
			First(&rt).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("load bot runtime %s for post quota: %w", agentKey, err)
		}

		if rt.QuotaResetDate == nil || !sameUTCDay(*rt.QuotaResetDate, today) {
			if err := tx.Model(&rt).Updates(map[string]any{
				"posts_today":      0,
				"quota_reset_date": today,
			}).Error; err != nil {
				return fmt.Errorf("reset post quota for bot %s: %w", agentKey, err)
			}
			rt.PostsToday = 0
		}
		if rt.PostQuotaDaily > 0 && rt.PostsToday >= rt.PostQuotaDaily {
			return errQuotaExceeded
		}
		if err := tx.Model(&rt).UpdateColumn("posts_today", gorm.Expr("posts_today + 1")).Error; err != nil {
			return fmt.Errorf("reserve post quota for bot %s: %w", agentKey, err)
		}
		reserved = true
		return nil
	})
	if err != nil {
		return nil, err
	}
	if !reserved {
		return noReservation, nil
	}

	return func() error {
		err := db.Model(&model.MoeAgentRuntime{}).
			Where(
				"agent_key = ? AND quota_reset_date = ? AND posts_today > ?",
				agentKey,
				today,
				0,
			).
			UpdateColumn("posts_today", gorm.Expr("posts_today - 1")).Error
		if err != nil {
			return fmt.Errorf("release post quota for bot %s: %w", agentKey, err)
		}
		return nil
	}, nil
}

func sameUTCDay(left, right time.Time) bool {
	leftYear, leftMonth, leftDay := left.UTC().Date()
	rightYear, rightMonth, rightDay := right.UTC().Date()
	return leftYear == rightYear && leftMonth == rightMonth && leftDay == rightDay
}

var errQuotaExceeded = errors.New("已达今日发帖配额")
