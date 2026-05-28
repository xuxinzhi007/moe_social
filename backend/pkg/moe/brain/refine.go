package brain

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

var refineJSONFence = regexp.MustCompile("(?s)```(?:json)?\\s*([\\s\\S]*?)```")

// RefineDeps 记忆润色依赖。
type RefineDeps struct {
	DB        *gorm.DB
	RPC       port.SuperPort
	Inference llminference.Config
}

// RefineOptions 单条润色选项。
type RefineOptions struct {
	MaxAttempts int
}

// CurateOptions 批量整理选项。
type CurateOptions struct {
	MaxEpisodes           int
	MaxAttemptsPerEpisode int
	MinQuality            int
	Force                 bool
}

// RefineResult 润色结果。
type RefineResult struct {
	EpisodeID     uint   `json:"episode_id"`
	OK            bool   `json:"ok"`
	Approved      bool   `json:"approved"`
	QualityScore  int    `json:"quality_score"`
	BeforeContent string `json:"before_content"`
	AfterContent  string `json:"after_content"`
	Attempts      int    `json:"attempts"`
	Detail        string `json:"detail"`
}

type refineLLMJSON struct {
	Content  string `json:"content"`
	MoodTag  string `json:"mood_tag"`
	Rationale string `json:"rationale"`
}

// RefineEpisode 对单条自传/记忆调用 LLM 润色，直到被认可或达最大次数。
func RefineEpisode(ctx context.Context, deps RefineDeps, episodeID uint, opts RefineOptions) (RefineResult, error) {
	out := RefineResult{EpisodeID: episodeID}
	if deps.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	if !deps.Inference.Ready() {
		return out, fmt.Errorf("未配置 llm_inference，无法润色记忆")
	}
	maxAttempts := opts.MaxAttempts
	if maxAttempts <= 0 {
		maxAttempts = 5
	}

	var ep model.MoeBotEpisode
	if err := deps.DB.First(&ep, episodeID).Error; err != nil {
		return out, err
	}
	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ?", ep.AgentKey).First(&rt).Error; err != nil {
		return out, err
	}
	forbidden := ParseTagList(rt.ForbiddenTags)
	preferred := ParseTagList(rt.PreferredTags)

	out.BeforeContent = ep.Content
	quality := EffectiveQuality(ep, forbidden)
	tags := parseTagsJSON(ep.TagsJSON)
	if !NeedsRefinement(quality, tags, forbidden) {
		out.OK = true
		out.Approved = true
		out.QualityScore = quality
		out.AfterContent = ep.Content
		out.Detail = "已达认可标准，无需润色"
		return out, nil
	}

	modelName := resolveRefineModel(deps, rt)
	current := ep.Content
	currentMood := ep.MoodTag
	var lastErr error

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		out.Attempts = attempt
		draft, err := callRefineLLM(ctx, deps, modelName, rt, ep, current, forbidden, preferred, quality, tags, attempt)
		if err != nil {
			lastErr = err
			continue
		}
		styleScore := poeticStyleScore(draft.Content)
		newTags := ExtractTags(draft.Content, draft.MoodTag, styleScore)
		newQuality := ComputeQualityScore(draft.Content, draft.MoodTag, styleScore, forbidden)
		if newQuality <= quality && attempt < maxAttempts {
			lastErr = fmt.Errorf("润色后质量未提升 (%d→%d)", quality, newQuality)
			current = draft.Content
			currentMood = draft.MoodTag
			continue
		}
		if err := applyEpisodeRefinement(ctx, deps, &ep, draft.Content, draft.MoodTag, styleScore, newQuality, newTags); err != nil {
			lastErr = err
			continue
		}
		out.OK = true
		out.Approved = IsApprovedQuality(newQuality) && !NeedsRefinement(newQuality, newTags, forbidden)
		out.QualityScore = newQuality
		out.AfterContent = draft.Content
		if out.Approved {
			out.Detail = fmt.Sprintf("第 %d 次润色后已认可（%d 分）", attempt, newQuality)
		} else {
			out.Detail = fmt.Sprintf("第 %d 次润色完成但未达阈值（%d 分）", attempt, newQuality)
		}
		return out, nil
	}
	if lastErr != nil {
		return out, lastErr
	}
	out.AfterContent = current
	out.QualityScore = ComputeQualityScore(current, currentMood, poeticStyleScore(current), forbidden)
	out.Detail = fmt.Sprintf("已尝试 %d 次，仍未达认可标准", maxAttempts)
	return out, fmt.Errorf("润色未成功: %s", out.Detail)
}

// CurateLowQuality 批量整理未认可或低分记忆。
func CurateLowQuality(ctx context.Context, deps RefineDeps, agentKey string, opts CurateOptions) ([]RefineResult, error) {
	if deps.DB == nil {
		return nil, fmt.Errorf("brain: db nil")
	}
	maxEpisodes := opts.MaxEpisodes
	if maxEpisodes <= 0 {
		maxEpisodes = 10
	}
	maxAttempts := opts.MaxAttemptsPerEpisode
	if maxAttempts <= 0 {
		maxAttempts = 5
	}
	minQuality := opts.MinQuality
	if minQuality <= 0 {
		minQuality = QualityApproveThreshold
	}

	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ?", strings.TrimSpace(agentKey)).First(&rt).Error; err != nil {
		return nil, err
	}
	forbidden := ParseTagList(rt.ForbiddenTags)

	var episodes []model.MoeBotEpisode
	if err := deps.DB.Where("agent_key = ?", rt.AgentKey).Order("created_at desc").Limit(maxEpisodes * 3).Find(&episodes).Error; err != nil {
		return nil, err
	}

	var targets []model.MoeBotEpisode
	for _, ep := range episodes {
		if len(targets) >= maxEpisodes {
			break
		}
		q := EffectiveQuality(ep, forbidden)
		tags := parseTagsJSON(ep.TagsJSON)
		if opts.Force || NeedsRefinement(q, tags, forbidden) || q < minQuality {
			targets = append(targets, ep)
		}
	}

	results := make([]RefineResult, 0, len(targets))
	for _, ep := range targets {
		res, err := RefineEpisode(ctx, deps, ep.ID, RefineOptions{MaxAttempts: maxAttempts})
		if err != nil && res.Detail == "" {
			res.Detail = err.Error()
		}
		results = append(results, res)
	}
	return results, nil
}

func applyEpisodeRefinement(
	ctx context.Context,
	deps RefineDeps,
	ep *model.MoeBotEpisode,
	content, moodTag string,
	styleScore, quality int,
	tags []string,
) error {
	var rt model.MoeAgentRuntime
	forbidden := []string{}
	if err := deps.DB.Where("agent_key = ?", ep.AgentKey).First(&rt).Error; err != nil {
		return err
	}
	forbidden = ParseTagList(rt.ForbiddenTags)
	tagsJSON, _ := json.Marshal(tags)
	updates := map[string]any{
		"content":        strings.TrimSpace(content),
		"mood_tag":       moodTag,
		"style_score":    styleScore,
		"quality_score":  quality,
		"tags_json":      string(tagsJSON),
		"revision_count": ep.RevisionCount + 1,
		"source":         "brain_refine",
		"approved":       IsApprovedQuality(quality) && !NeedsRefinement(quality, tags, forbidden),
	}
	if err := deps.DB.Model(ep).Updates(updates).Error; err != nil {
		return err
	}
	ep.Content = content
	ep.MoodTag = moodTag
	ep.RevisionCount++

	if deps.RPC != nil && ep.BotUserID > 0 && ep.MemoryKey != "" {
		val := fmt.Sprintf("%s\n标签: %s\n质量: %d", truncate(content, 200), strings.Join(tags, ", "), quality)
		_, _ = deps.RPC.UpsertUserMemory(ctx, &moe.UpsertUserMemoryReq{
			UserId:     strconv.FormatUint(uint64(ep.BotUserID), 10),
			Key:        ep.MemoryKey,
			Value:      val,
			MemoryType: "bot_episode",
			Source:     "moe_brain_refine",
			Confidence: float64(quality) / 100.0,
		})
	}
	if deps.RPC != nil && ep.PostID != "" && ep.BotUserID > 0 {
		_, _ = deps.RPC.UpdatePost(ctx, &moe.UpdatePostReq{
			PostId:  ep.PostID,
			UserId:  strconv.FormatUint(uint64(ep.BotUserID), 10),
			Content: content,
		})
	}
	return nil
}

func callRefineLLM(
	ctx context.Context,
	deps RefineDeps,
	modelName string,
	rt model.MoeAgentRuntime,
	ep model.MoeBotEpisode,
	current string,
	forbidden, preferred []string,
	quality int,
	tags []string,
	attempt int,
) (refineLLMJSON, error) {
	issues := describeIssues(quality, tags, forbidden)
	sys := strings.Join([]string{
		"你是 Moe 社区 Bot 的「记忆编辑助手」。",
		"任务：把一条质量不佳的自传/动态改写成更口语、更具体、更像真人朋友圈的版本。",
		"保留原意中的有效信息（如手绘进度），但换场景、换开头、换句式。",
		"禁止：剧本腔、星光/灵魂抒情、周X深夜+Moe社区套路开场。",
		"只输出 JSON：{\"content\":\"...\",\"mood_tag\":\"calm|happy|think|sad|excited\",\"rationale\":\"一句话说明改了什么\"}",
	}, "\n")
	user := strings.Join([]string{
		fmt.Sprintf("Bot：%s", rt.DisplayName),
		fmt.Sprintf("当前质量分：%d/100（目标≥%d）", quality, QualityApproveThreshold),
		"问题：" + issues,
		"禁止标签：" + strings.Join(forbidden, "、"),
		"偏好标签：" + strings.Join(preferred, "、"),
		"发帖硬性规则：\n" + strings.TrimSpace(rt.PostRules),
		"",
		"【待润色原文】",
		current,
		fmt.Sprintf("（第 %d 次润色，请明显不同于原文）", attempt),
	}, "\n")

	raw, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{
		Temperature: 0.85 + float64(attempt-1)*0.04,
		TopP:        0.92,
		MaxTokens:   512,
	})
	if err != nil {
		return refineLLMJSON{}, err
	}
	return parseRefineJSON(raw)
}

func describeIssues(quality int, tags, forbidden []string) string {
	var parts []string
	if quality < QualityApproveThreshold {
		parts = append(parts, fmt.Sprintf("分数偏低(%d)", quality))
	}
	for _, t := range tags {
		if strings.HasPrefix(t, "risk:") || t == "type:套路开场" {
			parts = append(parts, t)
		}
	}
	if hits := TagsConflict(tags, forbidden); len(hits) > 0 {
		parts = append(parts, "命中禁止:"+strings.Join(hits, ","))
	}
	if len(parts) == 0 {
		return "表达偏模板化"
	}
	return strings.Join(parts, "；")
}

func parseRefineJSON(raw string) (refineLLMJSON, error) {
	raw = strings.TrimSpace(raw)
	if m := refineJSONFence.FindStringSubmatch(raw); len(m) > 1 {
		raw = strings.TrimSpace(m[1])
	}
	var out refineLLMJSON
	if err := json.Unmarshal([]byte(raw), &out); err == nil && strings.TrimSpace(out.Content) != "" {
		return out, nil
	}
	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start >= 0 && end > start {
		if err := json.Unmarshal([]byte(raw[start:end+1]), &out); err == nil && strings.TrimSpace(out.Content) != "" {
			return out, nil
		}
	}
	return refineLLMJSON{}, fmt.Errorf("无法解析润色 JSON")
}

func poeticStyleScore(content string) int {
	lower := strings.ToLower(strings.TrimSpace(content))
	strong := []string{"灵魂", "星辰", "灯火", "共鸣", "深夜时分", "静静等待"}
	weak := []string{"宁静", "沉浸", "光芒", "陪伴", "时光", "诗意", "星光"}
	score := 0
	for _, m := range strong {
		if strings.Contains(lower, m) {
			score += 2
		}
	}
	for _, m := range weak {
		if strings.Contains(lower, m) {
			score++
		}
	}
	return score
}

func resolveRefineModel(deps RefineDeps, rt model.MoeAgentRuntime) string {
	if m := strings.TrimSpace(loadBotPostModelFromViper()); m != "" {
		return m
	}
	if m := strings.TrimSpace(deps.Inference.DefaultModel); m != "" {
		return m
	}
	if m := strings.TrimSpace(rt.ModelName); m != "" {
		return m
	}
	return "qwen2"
}

func loadBotPostModelFromViper() string {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return ""
	}
	if m := strings.TrimSpace(v.GetString("moe.bot_post_model")); m != "" {
		return m
	}
	return ""
}
