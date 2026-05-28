package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"
)

var (
	jsonFenceRe    = regexp.MustCompile("(?s)```(?:json)?\\s*([\\s\\S]*?)```")
	contentFieldRe = regexp.MustCompile(`(?s)"content"\s*:\s*"((?:\\.|[^"\\])*)`)
	moodFieldRe    = regexp.MustCompile(`"mood_tag"\s*:\s*"([^"\\]*)"`)
)

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
// rec 非空时写入动态子步骤（话题画像、每次 LLM、质检结论），供管理台流水线展示。
func generatePostContent(
	ctx context.Context,
	deps Deps,
	rt model.MoeAgentRuntime,
	rec *StepRecorder,
) (GeneratedPost, []GenAttemptRecord, error) {
	genPhaseStart := time.Now()
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

	if rec != nil {
		rec.BeginStep("topic_profile", "分析话题画像")
		t0 := time.Now()
		overused := brain.ListOverusedTopics(deps.DB, rt.AgentKey, 3, 10)
		rec.Add("topic_profile", "分析话题画像", "ok",
			fmt.Sprintf("近期帖 %d 条 · 过多话题 %d 项", len(recent), len(overused)), time.Since(t0))
	}

	ctxBlock := gatherPostContext(ctx, deps, rt)
	modelName, pick, pickErr := ResolvePostModelForRuntime(ctx, deps, rt)
	if pickErr != nil {
		return GeneratedPost{}, nil, pickErr
	}
	_ = pick
	if rec != nil {
		rec.BeginStep("resolve_model", "解析发帖模型")
		rec.Add("resolve_model", "解析发帖模型", "ok", modelName, time.Since(genPhaseStart))
	}
	persona := sanitizePersona(rt.SystemPrompt, rt)
	rulesBlock := formatPostRulesBlock(rt)
	brainBlock := ""
	if deps.DB != nil {
		eps := brain.ListRecentEpisodes(deps.DB, rt.AgentKey, 20)
		brainBlock = brain.PolicyBlock(rt, eps, deps.DB)
	}
	if rec != nil {
		rec.BeginStep("assemble_prompt", "组装发帖 Prompt")
		rec.Add("assemble_prompt", "组装发帖 Prompt", "ok",
			fmt.Sprintf("自传 %d 条 · 策略块 %d 字", len(episodes), len(brainBlock)), time.Since(genPhaseStart))
	}

	var (
		lastErr     error
		fallback    []postGenCandidate
		rejectNovel string
		attempts    []GenAttemptRecord
	)
	for attempt := 1; attempt <= maxGenerateAttempts; attempt++ {
		if rec != nil {
			rec.BeginStep("generate", "LLM 生成正文")
		}
		attemptStart := time.Now()
		stability := brain.EffectiveStabilityScore(rt)
		gen, err := callPostLLM(ctx, deps, modelName, persona, rulesBlock, brainBlock, ctxBlock, recent, attempt, rejectNovel, stability)
		if err != nil {
			lastErr = err
			rejectNovel = ""
			if strings.Contains(err.Error(), "无法解析 LLM JSON") {
				rejectNovel = "json"
				ctxBlock.topicHint = "只输出一行 JSON，不要 markdown、不要前缀说明、content 内不要用未转义换行"
			}
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeLLMError,
				Note:    genAttemptNote(err),
			})
			recordGenAttemptStep(rec, attempt, "fail", GenOutcomeLLMError, "", genAttemptNote(err), time.Since(attemptStart), attempts)
			continue
		}
		if contentTooSimilar(gen.Content, recent) {
			lastErr = fmt.Errorf("与近期帖重复")
			ctxBlock.topicHint = "必须换全新角度，禁止复述【本 Bot 近期已发】里的任何句子"
			rejectNovel = "duplicate"
			brain.NoteRejectedContent(ctx, brain.Deps{DB: deps.DB, Inference: deps.Inference}, rt.AgentKey, gen.Content, gen.MoodTag, novelStyleScore(gen.Content))
			ctxBlock.topicAvoid = appendTopicAvoid(ctxBlock.topicAvoid, gen.Content)
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeDuplicate,
				Snippet: genSnippet(gen.Content),
			})
			recordGenAttemptStep(rec, attempt, "fail", GenOutcomeDuplicate, genSnippet(gen.Content), "与近期帖重复", time.Since(attemptStart), attempts)
			continue
		}
		if meaningTooSimilar(gen.Content, recent, episodes) {
			lastErr = fmt.Errorf("与近期动态意思太像")
			ctxBlock.topicHint = "换场景：别写深夜星光抒情，改具体小事/吐槽/进度数字"
			rejectNovel = "theme"
			brain.NoteRejectedContent(ctx, brain.Deps{DB: deps.DB, Inference: deps.Inference}, rt.AgentKey, gen.Content, gen.MoodTag, novelStyleScore(gen.Content))
			ctxBlock.topicAvoid = appendTopicAvoid(ctxBlock.topicAvoid, gen.Content)
			fallback = append(fallback, postGenCandidate{gen: gen, score: 10, attempt: attempt})
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeTheme,
				Snippet: genSnippet(gen.Content),
			})
			recordGenAttemptStep(rec, attempt, "fail", GenOutcomeTheme, genSnippet(gen.Content), "意思太像", time.Since(attemptStart), attempts)
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
				recordGenAttemptStep(rec, attempt, "fail", GenOutcomeForbidden, genSnippet(gen.Content), strings.Join(hits, "、"), time.Since(attemptStart), attempts)
				continue
			}
			gen.Source = fmt.Sprintf("llm#%d", attempt)
			attempts = append(attempts, GenAttemptRecord{
				Attempt: attempt,
				Outcome: GenOutcomeOK,
				Snippet: genSnippet(gen.Content),
			})
			recordGenAttemptStep(rec, attempt, "ok", GenOutcomeOK, genSnippet(gen.Content), fmt.Sprintf("质量分约 %d", score), time.Since(attemptStart), attempts)
			if rec != nil {
				rec.Add("generate_finalize", "生成质检汇总", "ok",
					FormatGenStepDetail(attempts, true, gen.Source), time.Since(genPhaseStart))
			}
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
		recordGenAttemptStep(rec, attempt, "fail", GenOutcomeNovel, genSnippet(gen.Content), fmt.Sprintf("剧本腔 %d", score), time.Since(attemptStart), attempts)
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
		if rec != nil {
			rec.Add("generate_finalize", "生成质检汇总", "ok",
				FormatGenStepDetail(attempts, true, best.gen.Source)+"（放宽）", time.Since(genPhaseStart))
		}
		return best.gen, attempts, nil
	}
	if rec != nil {
		rec.Add("generate_finalize", "生成质检汇总", "fail",
			FormatGenStepDetail(attempts, false, ""), time.Since(genPhaseStart))
	}
	if lastErr != nil {
		return GeneratedPost{}, attempts, lastErr
	}
	return GeneratedPost{}, attempts, fmt.Errorf("多次生成仍不符合要求，请调整发帖规则或检查 llama-server")
}

func recordGenAttemptStep(rec *StepRecorder, attempt int, status string, outcome GenAttemptOutcome, snippet, note string, dur time.Duration, attempts []GenAttemptRecord) {
	if rec == nil {
		return
	}
	key := fmt.Sprintf("gen_attempt_%d", attempt)
	rec.BeginStep(key, fmt.Sprintf("生成尝试 #%d", attempt))
	detail := string(outcome)
	if snippet != "" {
		detail += " · " + snippet
	}
	if note != "" {
		detail += "（" + note + "）"
	}
	rec.Add(key, fmt.Sprintf("LLM 生成 #%d", attempt), status, detail, dur)
	if rec.live != nil && len(attempts) > 0 {
		rec.live.SyncGenAttempts(attempts)
	}
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
	stabilityScore int,
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
		brain.StabilityGenerationHint(stabilityScore),
		"【时段】" + ctxBlock.timeHint,
		"【创作提示】" + ctxBlock.topicHint,
		"",
		ctxBlock.meaningBlock,
	}
	if strings.TrimSpace(ctxBlock.topicAvoid) != "" {
		userParts = append(userParts, "", ctxBlock.topicAvoid)
	}
	userParts = append(userParts, "",
		"【本 Bot 近期已发 — 禁止重复】",
		ctxBlock.ownPosts,
		"",
		"【社区脉搏 — 其他用户近期动态】",
		ctxBlock.posts,
		"",
		"【Bot 记忆】",
		ctxBlock.memories,
	)
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
		case "json":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：上次 JSON 非法，只输出 {\"content\":\"一句口语\",\"mood_tag\":\"calm\"}，不要其它字符）", attempt))
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
	if rejectKind == "" && attempt > 1 {
		// JSON 解析失败后的重试：强制更短、更稳
		temp = 0.68
	}
	temp = brain.AdjustTemperatureForStability(stabilityScore, temp)
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
	if loose, err := looseExtractPostJSON(raw); err == nil && strings.TrimSpace(loose.Content) != "" {
		return loose, nil
	}
	return postGenJSON{}, fmt.Errorf("无法解析 LLM JSON: %s", truncateRunes(raw, 120))
}

// looseExtractPostJSON 小模型常输出截断/脏 JSON，尽量抽出 content 与 mood_tag。
func looseExtractPostJSON(raw string) (postGenJSON, error) {
	if m := contentFieldRe.FindStringSubmatch(raw); len(m) > 1 {
		content, err := strconv.Unquote(`"` + m[1] + `"`)
		if err != nil {
			content = strings.ReplaceAll(m[1], `\"`, `"`)
		}
		content = strings.TrimSpace(content)
		if content != "" {
			out := postGenJSON{Content: content}
			if mm := moodFieldRe.FindStringSubmatch(raw); len(mm) > 1 {
				out.MoodTag = mm[1]
			}
			return out, nil
		}
	}
	if content := extractTruncatedContentValue(raw); content != "" {
		return postGenJSON{Content: content}, nil
	}
	return postGenJSON{}, fmt.Errorf("loose extract failed")
}

func extractTruncatedContentValue(raw string) string {
	lower := strings.ToLower(raw)
	idx := strings.Index(lower, `"content"`)
	if idx < 0 {
		return ""
	}
	rest := raw[idx+len(`"content"`):]
	rest = strings.TrimSpace(rest)
	if !strings.HasPrefix(rest, ":") {
		return ""
	}
	rest = strings.TrimSpace(strings.TrimPrefix(rest, ":"))
	if len(rest) == 0 || rest[0] != '"' {
		return ""
	}
	rest = rest[1:]
	var b strings.Builder
	for i := 0; i < len(rest); i++ {
		if rest[i] == '\\' && i+1 < len(rest) {
			b.WriteByte(rest[i+1])
			i++
			continue
		}
		if rest[i] == '"' {
			break
		}
		b.WriteByte(rest[i])
	}
	return strings.TrimSpace(b.String())
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
