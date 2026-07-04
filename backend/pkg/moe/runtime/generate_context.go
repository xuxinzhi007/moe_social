package runtime

import (
	"context"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/postpulse"

	"gorm.io/gorm"
)

const (
	botRecentPostLimit  = 12
	communityPostLimit  = 8
	maxGenerateAttempts = 5
	duplicateSimilarMin = 0.68
)

// postContextBlock 注入 LLM 的上下文块。
type postContextBlock struct {
	ownPosts     string
	posts        string
	memories     string
	userProfile  string
	timeHint     string
	topicHint    string
	meaningBlock string
	topicAvoid   string
}

func gatherPostContext(ctx context.Context, deps Deps, rt model.MoeAgentRuntime) postContextBlock {
	_ = ctx
	out := postContextBlock{
		ownPosts:    "（暂无）",
		posts:       "（暂无）",
		memories:    "（暂无）",
		userProfile: "（暂无）",
		timeHint:    buildTimeHint(time.Now()),
		topicHint:   "可写一条轻松的日常或互动提问",
	}
	if deps.DB != nil && rt.BotUserID > 0 {
		if profile := buildUserProfileBlock(deps.DB, rt); profile != "" {
			out.userProfile = profile
		}
	}
	if deps.DB != nil && rt.BotUserID > 0 {
		if own := listBotRecentPosts(deps.DB, rt.BotUserID, botRecentPostLimit); len(own) > 0 {
			lines := make([]string, 0, len(own))
			for _, p := range own {
				lines = append(lines, fmt.Sprintf("- [%s] %s", p.CreatedAt.Format("01-02 15:04"), truncateRunes(p.Content, 100)))
			}
			out.ownPosts = strings.Join(lines, "\n")
		}
	}
	if deps.DB != nil {
		hits, err := postpulse.KeywordSearch(ctx, deps.DB, postpulse.SearchOptions{
			Limit:     communityPostLimit,
			ViewerUID: rt.BotUserID,
		})
		if err == nil && len(hits) > 0 {
			lines := make([]string, 0, len(hits))
			for _, h := range hits {
				lines = append(lines, fmt.Sprintf("- @%s: %s", h.UserName, h.Snippet))
			}
			out.posts = strings.Join(lines, "\n")
			if h := hits[0]; h.Snippet != "" {
				out.topicHint = fmt.Sprintf("可回应或延展站友话题：「%s」", truncateRunes(h.Snippet, 40))
			}
		}
	}
	if block := brain.BuildPostMemoryBlock(ctx, deps.DB, deps.RPC, rt); block != "" {
		out.memories = block
	}
	var episodes []model.MoeBotEpisode
	if deps.DB != nil {
		episodes = brain.ListRecentEpisodes(deps.DB, rt.AgentKey, 12)
	}
	var recentPosts []model.Post
	if deps.DB != nil && rt.BotUserID > 0 {
		recentPosts = listBotRecentPosts(deps.DB, rt.BotUserID, botRecentPostLimit)
	}
	out.meaningBlock = buildMeaningAwareBlock(recentPosts, episodes)
	if deps.DB != nil {
		out.topicAvoid = brain.BuildTopicDiversityBlock(rt, episodes, deps.DB)
	}
	return out
}

func listBotRecentPosts(db *gorm.DB, botUserID uint, limit int) []model.Post {
	var rows []model.Post
	_ = db.Where("user_id = ?", botUserID).
		Order("created_at desc").
		Limit(limit).
		Find(&rows).Error
	return rows
}

func buildUserProfileBlock(db *gorm.DB, rt model.MoeAgentRuntime) string {
	if db == nil || rt.BotUserID == 0 {
		return ""
	}
	var user model.User
	if err := db.Select("id", "username", "signature", "is_vip", "bot_agent_key").First(&user, rt.BotUserID).Error; err != nil {
		return ""
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("账号：@%s", firstNonEmpty(strings.TrimSpace(user.Username), rt.DisplayName, rt.AgentKey)))
	if sig := strings.TrimSpace(user.Signature); sig != "" {
		lines = append(lines, "签名："+truncateRunes(sig, 48))
	}
	if prefs := normalizeTagLines(rt.PreferredTags, 4); len(prefs) > 0 {
		lines = append(lines, "偏好主题："+strings.Join(prefs, "、"))
	}

	followingNames := listFollowingNames(db, rt.BotUserID, 5)
	if len(followingNames) > 0 {
		lines = append(lines, "关注对象："+strings.Join(followingNames, "、"))
	}

	likedSnippets := listRecentLikedPostSnippets(db, rt.BotUserID, 3)
	if len(likedSnippets) > 0 {
		lines = append(lines, "近期点赞倾向：")
		for _, s := range likedSnippets {
			lines = append(lines, "- "+s)
		}
	}

	followingSnippets := listFollowingRecentPostSnippets(db, rt.BotUserID, 3)
	if len(followingSnippets) > 0 {
		lines = append(lines, "关注流最近在聊：")
		for _, s := range followingSnippets {
			lines = append(lines, "- "+s)
		}
	}

	return strings.Join(lines, "\n")
}

func listFollowingNames(db *gorm.DB, userID uint, limit int) []string {
	if db == nil || userID == 0 || limit <= 0 {
		return nil
	}
	var rows []struct {
		Username string
	}
	_ = db.Table("follows AS f").
		Select("u.username").
		Joins("JOIN users u ON u.id = f.following_id").
		Where("f.follower_id = ?", userID).
		Order("f.created_at desc").
		Limit(limit).
		Scan(&rows).Error
	out := make([]string, 0, len(rows))
	seen := map[string]bool{}
	for _, row := range rows {
		name := strings.TrimSpace(row.Username)
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		out = append(out, name)
	}
	return out
}

func listRecentLikedPostSnippets(db *gorm.DB, userID uint, limit int) []string {
	if db == nil || userID == 0 || limit <= 0 {
		return nil
	}
	var rows []struct {
		Content  string
		Username string
	}
	_ = db.Table("likes AS l").
		Select("p.content, u.username").
		Joins("JOIN posts p ON p.id = l.target_id").
		Joins("JOIN users u ON u.id = p.user_id").
		Where("l.user_id = ? AND l.target_type = ?", userID, "post").
		Where("(p.moderation_status IS NULL OR p.moderation_status = '' OR p.moderation_status = 'ok')").
		Order("l.created_at desc").
		Limit(limit).
		Scan(&rows).Error
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		snippet := strings.TrimSpace(row.Content)
		if snippet == "" {
			continue
		}
		out = append(out, fmt.Sprintf("@%s：%s", strings.TrimSpace(row.Username), truncateRunes(snippet, 42)))
	}
	return out
}

func listFollowingRecentPostSnippets(db *gorm.DB, userID uint, limit int) []string {
	if db == nil || userID == 0 || limit <= 0 {
		return nil
	}
	var rows []struct {
		Content  string
		Username string
	}
	sub := db.Table("follows").Select("following_id").Where("follower_id = ?", userID)
	_ = db.Table("posts AS p").
		Select("p.content, u.username").
		Joins("JOIN users u ON u.id = p.user_id").
		Where("p.user_id IN (?)", sub).
		Where("(p.moderation_status IS NULL OR p.moderation_status = '' OR p.moderation_status = 'ok')").
		Order("p.created_at desc").
		Limit(limit).
		Scan(&rows).Error
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		snippet := strings.TrimSpace(row.Content)
		if snippet == "" {
			continue
		}
		out = append(out, fmt.Sprintf("@%s：%s", strings.TrimSpace(row.Username), truncateRunes(snippet, 42)))
	}
	return out
}

func normalizeTagLines(raw string, limit int) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" || limit <= 0 {
		return nil
	}
	fields := strings.FieldsFunc(raw, func(r rune) bool {
		return r == '\n' || r == ',' || r == '，'
	})
	out := make([]string, 0, len(fields))
	for _, field := range fields {
		field = strings.TrimSpace(field)
		if field == "" {
			continue
		}
		field = strings.TrimPrefix(field, "topic:")
		field = strings.TrimPrefix(field, "scene:")
		field = strings.TrimPrefix(field, "activity:")
		field = strings.TrimPrefix(field, "opening:")
		field = strings.TrimPrefix(field, "risk:")
		out = append(out, field)
		if len(out) >= limit {
			break
		}
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		v = strings.TrimSpace(v)
		if v != "" {
			return v
		}
	}
	return ""
}

func buildTimeHint(now time.Time) string {
	week := []string{"日", "一", "二", "三", "四", "五", "六"}[now.Weekday()]
	slot := "白天"
	switch h := now.Hour(); {
	case h < 6:
		slot = "深夜"
	case h < 11:
		slot = "上午"
	case h < 14:
		slot = "中午"
	case h < 18:
		slot = "下午"
	case h < 22:
		slot = "晚上"
	default:
		slot = "夜里"
	}
	return fmt.Sprintf("参考时段：周%s %s（%s）。注意：不要把「周%s的深夜，Moe社区」写进正文开头；用具体小事开场。",
		week, now.Format("15:04"), slot, week)
}

// sanitizePersona 过滤误写入库的占位/指令式 system_prompt。
func sanitizePersona(raw string, rt model.MoeAgentRuntime) string {
	s := strings.TrimSpace(raw)
	if s == "" || isInstructionLikePersona(s) {
		return fmt.Sprintf("你是社区 AI「%s」，擅长结合站内动态写原创短帖，语气自然、不重复套路。", displayName(rt))
	}
	return s
}

func isInstructionLikePersona(s string) bool {
	lower := strings.ToLower(s)
	markers := []string{
		"简短友善的社区引导语",
		"发一条不超过",
		"不超过 80 字",
		"不超过80字",
		"今日也在 moe 社区和大家见面",
		"有什么想聊的吗",
		"请生成",
		"输出 json",
	}
	hits := 0
	for _, m := range markers {
		if strings.Contains(lower, strings.ToLower(m)) {
			hits++
		}
	}
	return hits >= 1 && utf8.RuneCountInString(s) < 120
}

func normalizeForCompare(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var b strings.Builder
	for _, r := range s {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r >= 0x4e00 && r <= 0x9fff {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// contentTooSimilar 与 Bot 近期帖或已知模板句判重。
func contentTooSimilar(content string, recent []model.Post) bool {
	normNew := normalizeForCompare(content)
	if normNew == "" {
		return true
	}
	for _, tpl := range []string{
		"今日也在moe社区和大家见面啦有什么想聊的吗",
		"简短友善的社区引导语发一条不超过80字的动态",
	} {
		if strings.Contains(normNew, tpl) || similarityRatio(normNew, tpl) >= duplicateSimilarMin {
			return true
		}
	}
	for _, p := range recent {
		normOld := normalizeForCompare(p.Content)
		if normOld == "" {
			continue
		}
		if normNew == normOld {
			return true
		}
		if similarityRatio(normNew, normOld) >= duplicateSimilarMin {
			return true
		}
		if len(normNew) > 20 && len(normOld) > 20 {
			if strings.Contains(normNew, normOld) || strings.Contains(normOld, normNew) {
				return true
			}
		}
	}
	return false
}

func similarityRatio(a, b string) float64 {
	if a == "" || b == "" {
		return 0
	}
	if a == b {
		return 1
	}
	bgA := bigrams(a)
	bgB := bigrams(b)
	if len(bgA) == 0 || len(bgB) == 0 {
		return 0
	}
	inter := 0
	for k := range bgA {
		if bgB[k] {
			inter++
		}
	}
	union := len(bgA) + len(bgB) - inter
	if union <= 0 {
		return 0
	}
	return float64(inter) / float64(union)
}

func bigrams(s string) map[string]bool {
	runes := []rune(s)
	out := make(map[string]bool)
	if len(runes) < 2 {
		out[s] = true
		return out
	}
	for i := 0; i < len(runes)-1; i++ {
		out[string(runes[i:i+2])] = true
	}
	return out
}
