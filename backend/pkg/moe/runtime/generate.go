package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"

	"gorm.io/gorm"
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
	gen            GeneratedPost
	quality        int
	attempt        int
	directionIndex int
}

var postScenarioHints = []string{
	"从一个刚发生的细节切入，写清它为什么让你停下来；不必强行提问。",
	"分享一个正在做的具体进度；只使用上下文里真实出现的数字，没有数字就写动作或细节。",
	"写一个小失误、意外或尝试后的结果，重点放在自己的反应，不要编造背景。",
	"回应社区里正在讨论的话题，补充自己的经历或不同角度，不复述原帖。",
	"分享一个明确的偏好，并用一句真实理由说明，不写成推荐广告。",
	"写一条轻松吐槽或小发现，换到与近期动态不同的日常场景。",
	"提出一个值得交流的小选择题，先交代具体缘由，只有自然时才以问题收尾。",
	"从近期记忆或账号兴趣里挑一个尚未重复的切口，讲一件具体的小事。",
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
	stability := brain.EffectiveStabilityScore(rt)
	policy := brain.GenerationPolicyForStability(stability)
	directionOffset := nextPostScenarioIndex(deps.DB, rt.AgentKey)
	forbidden := brain.ParseTagList(rt.ForbiddenTags)
	for attempt := 1; attempt <= policy.MaxGenerateAttempts; attempt++ {
		directionIndex := (directionOffset + attempt - 1) % len(postScenarioHints)
		if rec != nil {
			rec.BeginStep("generate", "LLM 生成正文")
		}
		attemptStart := time.Now()
		gen, err := callPostLLM(
			ctx,
			deps,
			modelName,
			persona,
			rulesBlock,
			brainBlock,
			ctxBlock,
			recent,
			attempt,
			directionIndex,
			rejectNovel,
			stability,
			rec,
		)
		if err != nil {
			lastErr = err
			rejectNovel = ""
			if strings.Contains(err.Error(), "无法解析 LLM JSON") {
				rejectNovel = "json"
				ctxBlock.topicHint = "只输出一行 JSON，不要 markdown、不要前缀说明、content 内不要用未转义换行"
			}
			attempts = append(attempts, GenAttemptRecord{
				Attempt:        attempt,
				DirectionIndex: directionIndex,
				Outcome:        GenOutcomeLLMError,
				Note:           genAttemptNote(err),
			})
			recordGenAttemptStep(rec, attempt, "fail", GenOutcomeLLMError, "", genAttemptNote(err), time.Since(attemptStart), attempts)
			continue
		}
		candidate, outcome, note := reviewPostCandidate(gen, rt, recent, episodes, forbidden, true)
		candidate.attempt = attempt
		candidate.directionIndex = directionIndex
		if outcome != GenOutcomeOK {
			lastErr = fmt.Errorf("%s", note)
			switch outcome {
			case GenOutcomeDuplicate:
				rejectNovel = "duplicate"
				ctxBlock.topicHint = "换一个近期没有出现过的主题、开头和细节，不要复述旧动态。"
			case GenOutcomeTheme:
				rejectNovel = "theme"
				ctxBlock.topicHint = "更换场景、叙事视角和句式，避免复用近期动态的主题或开头。"
				fallback = append(fallback, candidate)
			case GenOutcomeForbidden:
				rejectNovel = "forbidden"
				ctxBlock.topicHint = "避开这些明确禁止的标签：" + note
			case GenOutcomeQuality:
				rejectNovel = "quality"
				ctxBlock.topicHint = "补充一个真实、具体且有信息量的细节，不要用空泛感叹凑字数。"
			case GenOutcomeNovel:
				rejectNovel = "novel"
				ctxBlock.topicHint = "改用自然口语和具体经历，避免诗意套话或固定开场。"
			}
			if outcome == GenOutcomeDuplicate || outcome == GenOutcomeTheme {
				brain.NoteRejectedContent(
					ctx,
					brain.Deps{DB: deps.DB},
					rt.AgentKey,
					gen.Content,
					gen.MoodTag,
					novelStyleScore(gen.Content),
				)
				ctxBlock.topicAvoid = appendTopicAvoid(ctxBlock.topicAvoid, gen.Content)
			}
			attempts = append(attempts, GenAttemptRecord{
				Attempt:        attempt,
				DirectionIndex: directionIndex,
				Outcome:        outcome,
				Snippet:        genSnippet(gen.Content),
				Note:           note,
			})
			recordGenAttemptStep(
				rec,
				attempt,
				"fail",
				outcome,
				genSnippet(gen.Content),
				note,
				time.Since(attemptStart),
				attempts,
			)
			continue
		}
		candidate.gen.Source = fmt.Sprintf("llm#%d", attempt)
		attempts = append(attempts, GenAttemptRecord{
			Attempt:        attempt,
			DirectionIndex: directionIndex,
			Outcome:        GenOutcomeOK,
			Snippet:        genSnippet(candidate.gen.Content),
			Note:           note,
		})
		recordGenAttemptStep(
			rec,
			attempt,
			"ok",
			GenOutcomeOK,
			genSnippet(candidate.gen.Content),
			note,
			time.Since(attemptStart),
			attempts,
		)
		if rec != nil {
			rec.Add(
				"generate_finalize",
				"生成质检汇总",
				"ok",
				FormatGenStepDetail(attempts, true, candidate.gen.Source),
				time.Since(genPhaseStart),
			)
		}
		return candidate.gen, attempts, nil
	}

	// Stable bots may relax semantic similarity only after all hard quality checks pass.
	if policy.AllowRelaxedFallback {
		if best := pickBestNovelFallback(fallback, rt, recent, forbidden); best != nil {
			best.gen.Source = fmt.Sprintf("llm#%d-relaxed", best.attempt)
			attempts = append(attempts, GenAttemptRecord{
				Attempt:        best.attempt,
				DirectionIndex: best.directionIndex,
				Outcome:        GenOutcomeOK,
				Snippet:        genSnippet(best.gen.Content),
				Note:           fmt.Sprintf("语义相似放宽；质量分 %d/100", best.quality),
			})
			if rec != nil {
				rec.Add("generate_finalize", "生成质检汇总", "ok",
					FormatGenStepDetail(attempts, true, best.gen.Source)+"（放宽）", time.Since(genPhaseStart))
			}
			return best.gen, attempts, nil
		}
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

func reviewPostCandidate(
	gen GeneratedPost,
	rt model.MoeAgentRuntime,
	recent []model.Post,
	episodes []model.MoeBotEpisode,
	forbidden []string,
	checkSemanticSimilarity bool,
) (postGenCandidate, GenAttemptOutcome, string) {
	candidate := postGenCandidate{
		gen:     gen,
		attempt: 0,
	}
	if contentTooSimilar(gen.Content, recent) {
		return candidate, GenOutcomeDuplicate, "与近期已发正文重复"
	}

	styleScore := novelStyleScore(gen.Content)
	if hits := brain.EpisodeTagsViolate(gen.Content, gen.MoodTag, styleScore, forbidden); len(hits) > 0 {
		return candidate, GenOutcomeForbidden, strings.Join(hits, "、")
	}
	candidate.quality = brain.ComputeQualityScore(gen.Content, gen.MoodTag, styleScore, forbidden)
	tags := brain.ExtractTags(gen.Content, gen.MoodTag, styleScore)
	if !brain.IsApprovedQuality(candidate.quality) ||
		brain.NeedsRefinement(candidate.quality, tags, forbidden) {
		if styleScore >= novelStyleRejectThreshold {
			return candidate, GenOutcomeNovel, fmt.Sprintf(
				"诗意腔得分 %d，质量分 %d/100",
				styleScore,
				candidate.quality,
			)
		}
		return candidate, GenOutcomeQuality, fmt.Sprintf(
			"质量分 %d/100，目标 ≥ %d",
			candidate.quality,
			brain.QualityApproveThreshold,
		)
	}
	if hasBannedOpening(gen.Content) {
		return candidate, GenOutcomeTheme, "命中重复开头模式"
	}
	if checkSemanticSimilarity && meaningTooSimilar(gen.Content, recent, episodes) {
		return candidate, GenOutcomeTheme, "与近期动态意思太像"
	}
	return candidate, GenOutcomeOK, fmt.Sprintf("质量分 %d/100", candidate.quality)
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

func pickBestNovelFallback(
	cands []postGenCandidate,
	rt model.MoeAgentRuntime,
	recent []model.Post,
	forbidden []string,
) *postGenCandidate {
	if len(cands) == 0 {
		return nil
	}
	var best *postGenCandidate
	for i := range cands {
		c := &cands[i]
		reviewed, outcome, _ := reviewPostCandidate(c.gen, rt, recent, nil, forbidden, false)
		if outcome != GenOutcomeOK || hasBannedOpening(c.gen.Content) {
			continue
		}
		c.quality = reviewed.quality
		if best == nil || c.quality > best.quality {
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
	directionIndex int,
	rejectKind string,
	stabilityScore int,
	rec *StepRecorder,
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
		"任务：写一条有真实细节、能让社区愿意停下来读的原创动态，不是评论回复或公告。",
		"按本次创作方向选择一个切口，结合账号画像、记忆或社区脉搏；只写上下文支持的事实，不虚构经历、数字或外部信息。",
		"每条只表达一个清楚的想法。避免空泛感叹、万能问候、固定收尾和近期已经使用的开头/主题；提问不是必需。",
		"长短、语气、是否使用表情由内容自然决定，不要为了满足格式添加无意义句子。",
		"只输出 JSON：{\"content\":\"...\",\"mood_tag\":\"calm|happy|think|sad|excited\"}",
	}, "\n")

	userParts := []string{
		brain.StabilityGenerationHint(stabilityScore),
		"【本次创作方向】" + postScenarioHint(directionIndex),
		"【账号画像】\n" + ctxBlock.userProfile,
		"【时段】" + ctxBlock.timeHint,
		"【创作提示】" + ctxBlock.topicHint,
		"",
		ctxBlock.meaningBlock,
	}
	if strings.TrimSpace(ctxBlock.topicAvoid) != "" {
		userParts = append(userParts, "", ctxBlock.topicAvoid)
	}
	userParts = append(userParts, "",
		"【本 Bot 近期已用主题摘要 — 仅用于避开，不是写作范文】",
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
				fmt.Sprintf("（第 %d 次：上次太像散文/剧本腔，请改成自然口语，避免抒情套话）", attempt))
		case "duplicate":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：与历史重复，请换主题、换开头、换细节）", attempt))
		case "theme":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：与近期动态意思太像，请换场景、叙事视角和句式，不要沿用上一条结构）", attempt))
		case "quality":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：上次质量分未达标；加入具体且真实的细节，避免空话和套话）", attempt))
		case "json":
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次：上次 JSON 非法，只输出 {\"content\":\"一句口语\",\"mood_tag\":\"calm\"}，不要其它字符）", attempt))
		default:
			userParts = append(userParts, "",
				fmt.Sprintf("（第 %d 次重试，请换写法）", attempt))
		}
	}
	userParts = append(userParts, "", "请按本次方向输出一条自然、有细节且不复用近期表达的动态 JSON。")

	temp := 0.92 + float64(attempt-1)*0.03
	if rejectKind == "novel" && attempt > 1 {
		temp = 0.75 // 文艺腔重试时降温，更贴口语
	}
	if rejectKind == "" && attempt > 1 {
		// JSON 解析失败后的重试：强制更短、更稳
		temp = 0.68
	}
	temp = brain.AdjustTemperatureForStability(stabilityScore, temp)
	messages := []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: strings.Join(userParts, "\n")},
	}
	var streamed strings.Builder
	raw, err := llminference.ChatStream(ctx, deps.Inference, modelName, messages, llminference.ChatOptions{
		Temperature:   temp,
		TopP:          0.95,
		RepeatPenalty: 1.12,
		MaxTokens:     512,
	}, func(chunk string) error {
		streamed.WriteString(chunk)
		if rec != nil {
			preview := streamed.String()
			if len([]rune(preview)) > 1200 {
				preview = string([]rune(preview)[len([]rune(preview))-1200:])
			}
			rec.UpdateActiveDetail("实时生成：" + preview)
		}
		return nil
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

func postScenarioHint(index int) string {
	if index < 0 {
		index = 0
	}
	return postScenarioHints[index%len(postScenarioHints)]
}

func nextPostScenarioIndex(db *gorm.DB, agentKey string) int {
	if db != nil {
		if previous, err := LatestAgentRunLog(db, agentKey); err == nil {
			previousRun := ParseRunLog(previous.StepsJSON)
			if len(previousRun.GenerateAttempts) > 0 {
				return (previousRun.CreativeDirectionIndex + 1) % len(postScenarioHints)
			}
		}
	}
	hasher := fnv.New32a()
	_, _ = hasher.Write([]byte(strings.TrimSpace(agentKey)))
	return int(hasher.Sum32() % uint32(len(postScenarioHints)))
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
