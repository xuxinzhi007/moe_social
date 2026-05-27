package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"
)

var jsonFenceRe = regexp.MustCompile("(?s)```(?:json)?\\s*([\\s\\S]*?)```")

// GeneratedPost LLM 生成的发帖草稿。
type GeneratedPost struct {
	Content string
	MoodTag string
	Source  string
}

type postGenJSON struct {
	Content string `json:"content"`
	MoodTag string `json:"mood_tag"`
}

type postGenCandidate struct {
	gen     GeneratedPost
	score   int
	attempt int
}

// generatePostContent 调用本地模型生成不重复的社区短帖；attempts 仅含本次试跑内的生成次数。
func generatePostContent(ctx context.Context, deps Deps, rt model.MoeAgentRuntime) (GeneratedPost, []GenAttemptRecord, error) {
	if !deps.Inference.Ready() {
		return GeneratedPost{}, nil, fmt.Errorf("未配置 llm_inference.base_url，无法 AI 生成发帖")
	}

	var recent []model.Post
	var episodes []model.MoeBotEpisode
	if deps.DB != nil && rt.BotUserID > 0 {
		recent = listBotRecentPosts(deps.DB, rt.BotUserID, botRecentPostLimit)
	}
	if deps.DB != nil {
		episodes = brain.ListRecentEpisodes(deps.DB, rt.AgentKey, 12)
	}

	ctxBlock := gatherPostContext(ctx, deps, rt)
	modelName, pick, pickErr := ResolvePostModelForRuntime(ctx, deps, rt)
	if pickErr != nil {
		return GeneratedPost{}, nil, pickErr
	}
	_ = pick
	persona := sanitizePersona(rt.SystemPrompt, rt)
	rulesBlock := formatPostRulesBlock(rt)
	brainBlock := ""
	if deps.DB != nil {
		eps := brain.ListRecentEpisodes(deps.DB, rt.AgentKey, 20)
		brainBlock = brain.PolicyBlock(rt, eps)
	}

	var (
		lastErr     error
		fallback    []postGenCandidate
		rejectNovel string
		attempts    []GenAttemptRecord
	)
	for attempt := 1; attempt <= maxGenerateAttempts; attempt++ {
		gen, err := callPostLLM(ctx, deps, modelName, persona, rulesBlock, brainBlock, ctxBlock, recent, attempt, rejectNovel)
		if err != nil {
			lastErr = err
			rejectNovel = ""
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeLLMError,
				Note:    genAttemptNote(err),
			})
			continue
		}
		if contentTooSimilar(gen.Content, recent) {
			lastErr = fmt.Errorf("与近期帖重复")
			ctxBlock.topicHint = "必须换全新角度，禁止复述【本 Bot 近期已发】里的任何句子"
			rejectNovel = "duplicate"
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeDuplicate,
				Snippet: genSnippet(gen.Content),
			})
			continue
		}
		if meaningTooSimilar(gen.Content, recent, episodes) {
			lastErr = fmt.Errorf("与近期动态意思太像")
			ctxBlock.topicHint = "换场景：别写深夜星光抒情，改具体小事/吐槽/进度数字"
			rejectNovel = "theme"
			fallback = append(fallback, postGenCandidate{gen: gen, score: 10, attempt: attempt})
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeTheme,
				Snippet: genSnippet(gen.Content),
			})
			continue
		}
		score := novelStyleScore(gen.Content)
		if score < novelStyleRejectThreshold {
			forbidden := brain.ParseTagList(rt.ForbiddenTags)
			if hits := brain.EpisodeTagsViolate(gen.Content, gen.MoodTag, score, forbidden); len(hits) > 0 {
				lastErr = fmt.Errorf("命中禁止标签 %v", hits)
				rejectNovel = "novel"
				ctxBlock.topicHint = "禁止使用标签：" + strings.Join(hits, "、")
				fallback = append(fallback, postGenCandidate{gen: gen, score: score + 5, attempt: attempt})
				attempts = append(attempts, GenAttemptRecord{
					Attempt: attempt,
					Outcome: GenOutcomeForbidden,
					Snippet: genSnippet(gen.Content),
					Note:    strings.Join(hits, "、"),
				})
				continue
			}
			gen.Source = fmt.Sprintf("llm#%d", attempt)
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeOK,
				Snippet: genSnippet(gen.Content),
			})
			return gen, attempts, nil
		}
		fallback = append(fallback, postGenCandidate{gen: gen, score: score, attempt: attempt})
		lastErr = fmt.Errorf("偏剧本/诗意腔（得分 %d）", score)
		rejectNovel = "novel"
		ctxBlock.topicHint = "必须用口语：我在做什么+一个小细节，禁止抒情散文、禁止「灵魂/星辰/灯火/共鸣」"
		attempts = append(attempts, GenAttemptRecord{
			Attempt: attempt,
			Outcome: GenOutcomeNovel,
			Snippet: genSnippet(gen.Content),
			Note:    fmt.Sprintf("得分 %d", score),
		})
	}

	// 多次仍偏文艺：选得分最低且不与历史重复的一条发出，避免试跑永远失败
	if best := pickBestNovelFallback(fallback, recent, episodes); best != nil {
		best.gen.Source = fmt.Sprintf("llm#%d-relaxed", best.attempt)
		attempts = append(attempts, GenAttemptRecord{
			Attempt: best.attempt,
			Outcome: GenOutcomeOK,
			Snippet: genSnippet(best.gen.Content),
			Note:    "放宽质检后采用",
		})
		return best.gen, attempts, nil
	}
	if lastErr != nil {
		return GeneratedPost{}, attempts, lastErr
	}
	return GeneratedPost{}, attempts, fmt.Errorf("多次生成仍不符合要求，请调整发帖规则或检查 llama-server")
}

func pickBestNovelFallback(cands []postGenCandidate, recent []model.Post, episodes []model.MoeBotEpisode) *postGenCandidate {
	if len(cands) == 0 {
		return nil
	}
	var best *postGenCandidate
	for i := range cands {
		c := &cands[i]
		if contentTooSimilar(c.gen.Content, recent) {
			continue
		}
		if meaningTooSimilar(c.gen.Content, recent, episodes) {
			continue
		}
		if hasBannedOpening(c.gen.Content) {
			continue
		}
		if best == nil || c.score < best.score {
			best = c
		}
	}
	return best
}

func callPostLLM(
	ctx context.Context,
	deps Deps,
	modelName, persona, rulesBlock, brainBlock string,
	ctxBlock postContextBlock,
	recent []model.Post,
	attempt int,
	rejectKind string,
) (GeneratedPost, error) {
	sys := strings.Join([]string{
		communityPostGuardrails,
		"",
		rulesBlock,
		"",
		brainBlock,
		"",
		persona,
		"",
		"任务：写一条【全新】社区动态（不是评论回复）。",
		"步骤：先看【本 Bot 近期已发】避免重复 → 从【社区脉搏/记忆/时段】挑 1 个具体点 → 按硬性规则写成朋友圈口语。",
		"类型任选其一：晒进度 / 晒作品 / 求建议 / 轻松吐槽 / 回应站友话题。",
		"只输出 JSON：{\"content\":\"...\",\"mood_tag\":\"calm|happy|think|sad|excited\"}",
	}, "\n")

	userParts := []string{
		"【时段】" + ctxBlock.timeHint,
		"【创作提示】" + ctxBlock.topicHint,
		"",
		ctxBlock.meaningBlock,
		"",
		"【本 Bot 近期已发 — 禁止重复】",
		ctxBlock.ownPosts,
		"",
		"【社区脉搏 — 其他用户近期动态】",
		ctxBlock.posts,
		"",
		"【Bot 记忆】",
		ctxBlock.memories,
	}
	if attempt > 1 {
		switch rejectKind {
		case "novel":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：上次太像散文/剧本腔，请改成朋友圈口语，例如「刚画完线稿，手酸，你们周末干嘛」）", attempt))
		case "duplicate":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：与历史重复，请换主题、换开头、换细节）", attempt))
		case "theme":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：与近期动态「意思太像」（同深夜抒情/同开头），请换场景：具体小事、数字、吐槽，禁止星光/灯火/夜空抒情）", attempt))
		default:
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次重试，请换写法）", attempt))
		}
	}
	userParts = append(userParts, "", "请输出下一条【与历史完全不同】的动态 JSON。")

	temp := 0.92 + float64(attempt-1)*0.03
	if rejectKind == "novel" && attempt > 1 {
		temp = 0.75 // 文艺腔重试时降温，更贴口语
	}
	raw, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: strings.Join(userParts, "\n")},
	}, llminference.ChatOptions{
		Temperature: temp,
		TopP:        0.92,
		MaxTokens:   512,
	})
	if err != nil {
		return GeneratedPost{}, fmt.Errorf("LLM 生成失败: %w", err)
	}

	parsed, err := parsePostGenJSON(raw)
	if err != nil {
		return GeneratedPost{}, err
	}
	content := strings.TrimSpace(parsed.Content)
	if content == "" {
		return GeneratedPost{}, fmt.Errorf("LLM 返回空正文")
	}
	if n := utf8.RuneCountInString(content); n > 220 {
		content = string([]rune(content)[:220])
	}
	return GeneratedPost{Content: content, MoodTag: normalizeMoodTag(parsed.MoodTag)}, nil
}

func parsePostGenJSON(raw string) (postGenJSON, error) {
	raw = strings.TrimSpace(raw)
	if m := jsonFenceRe.FindStringSubmatch(raw); len(m) > 1 {
		raw = strings.TrimSpace(m[1])
	}
	var out postGenJSON
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
	return postGenJSON{}, fmt.Errorf("无法解析 LLM JSON: %s", truncateRunes(raw, 120))
}

func normalizeMoodTag(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "happy", "joy", "开心":
		return "happy"
	case "think", "thinking", "思考":
		return "think"
	case "sad", "难过":
		return "sad"
	case "excited", "兴奋":
		return "excited"
	default:
		return "calm"
	}
}

func displayName(rt model.MoeAgentRuntime) string {
	if n := strings.TrimSpace(rt.DisplayName); n != "" {
		return n
	}
	return rt.AgentKey
}

func truncateRunes(s string, max int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	return string([]rune(s)[:max]) + "…"
}
