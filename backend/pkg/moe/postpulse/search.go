package postpulse

import (
	"context"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"

	"gorm.io/gorm"
)

// SearchHit 动态检索命中项（可解释排序：关键词 + 热度 + 时间）。
type SearchHit struct {
	PostID      string  `json:"post_id"`
	UserID      string  `json:"user_id"`
	UserName    string  `json:"user_name"`
	Content     string  `json:"content"`
	Snippet     string  `json:"snippet"`
	MoodTag     string  `json:"mood_tag"`
	Likes       int     `json:"likes"`
	Comments    int     `json:"comments"`
	CreatedAt   string  `json:"created_at"`
	Score       float64 `json:"score"`
	ScoreReason string  `json:"score_reason"`
}

// SearchOptions Post Pulse P0 检索参数。
type SearchOptions struct {
	Query       string
	Limit       int
	ViewerUID   uint
	MoodTag     string
	TopicTagID  uint
	Explain     bool
}

// KeywordSearch 站内动态关键词检索（审核通过、非删除）。
func KeywordSearch(ctx context.Context, db *gorm.DB, opt SearchOptions) ([]SearchHit, error) {
	_ = ctx
	q := strings.TrimSpace(opt.Query)
	limit := opt.Limit
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}

	query := db.Model(&model.Post{}).
		Where("moderation_status = ? OR moderation_status = ''", "ok")

	if opt.MoodTag != "" {
		query = query.Where("mood_tag = ?", strings.TrimSpace(opt.MoodTag))
	}
	if opt.TopicTagID > 0 {
		sub := db.Model(&model.PostTopic{}).Select("post_id").Where("topic_tag_id = ?", opt.TopicTagID)
		query = query.Where("id IN (?)", sub)
	}

	tokens := tokenize(q)
	if len(tokens) > 0 {
		var conds []string
		var args []any
		for _, tok := range tokens {
			conds = append(conds, "content LIKE ?")
			args = append(args, "%"+tok+"%")
		}
		query = query.Where(strings.Join(conds, " OR "), args...)
	}

	query = query.Order("(likes * 2 + comments) DESC").Order("created_at DESC").Limit(limit * 3)

	var posts []model.Post
	if err := query.Find(&posts).Error; err != nil {
		return nil, err
	}

	userIDs := make([]uint, 0, len(posts))
	for _, p := range posts {
		userIDs = append(userIDs, p.UserID)
	}
	userMap := map[uint]model.User{}
	if len(userIDs) > 0 {
		var users []model.User
		_ = db.Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	hits := make([]SearchHit, 0, limit)
	for _, p := range posts {
		score, reason := scorePost(p, tokens)
		if len(tokens) > 0 && score <= 0 {
			continue
		}
		name := "用户"
		if u, ok := userMap[p.UserID]; ok && u.Username != "" {
			name = u.Username
		}
		content := strings.TrimSpace(p.Content)
		hits = append(hits, SearchHit{
			PostID:      uintToStr(p.ID),
			UserID:      uintToStr(p.UserID),
			UserName:    name,
			Content:     content,
			Snippet:     snippet(content, 120),
			MoodTag:     p.MoodTag,
			Likes:       p.Likes,
			Comments:    p.Comments,
			CreatedAt:   p.CreatedAt.Format(time.RFC3339),
			Score:       score,
			ScoreReason: reason,
		})
		if len(hits) >= limit {
			break
		}
	}
	return hits, nil
}

func scorePost(p model.Post, tokens []string) (float64, string) {
	norm := strings.ToLower(p.Content)
	var kw float64
	for _, tok := range tokens {
		if strings.Contains(norm, tok) {
			kw += 2
		}
	}
	hot := float64(p.Likes*2 + p.Comments)
	recency := 0.0
	if time.Since(p.CreatedAt) < 7*24*time.Hour {
		recency = 1
	}
	score := kw + hot*0.05 + recency
	reason := "热度+时间"
	if kw > 0 {
		reason = "关键词命中+" + reason
	}
	return score, reason
}

func tokenize(q string) []string {
	q = strings.ToLower(strings.TrimSpace(q))
	if q == "" {
		return nil
	}
	parts := strings.FieldsFunc(q, func(r rune) bool {
		return r == ' ' || r == ',' || r == '，' || r == '。'
	})
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if utf8.RuneCountInString(p) >= 2 || len(p) >= 2 {
			out = append(out, p)
		}
	}
	return out
}

func snippet(s string, max int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	runes := []rune(s)
	return string(runes[:max]) + "…"
}

func uintToStr(id uint) string {
	return strconv.FormatUint(uint64(id), 10)
}
