package brain

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"backend/pkg/llminference"

	"github.com/spf13/viper"
)

var topicAnalyzeJSONFence = regexp.MustCompile("(?s)```(?:json)?\\s*([\\s\\S]*?)```")

// TopicAnalysis 单条正文的话题结构化结果（规则 + 可选 LLM）。
type TopicAnalysis struct {
	Scene          string   `json:"scene"`
	Activity       string   `json:"activity"`
	OpeningPattern string   `json:"opening_pattern"`
	SemanticKey    string   `json:"semantic_key"`
	Themes         []string `json:"themes"`
	Tags           []string `json:"tags"`
	Source         string   `json:"source"`
}

type topicAnalyzeLLMJSON struct {
	Scene          string   `json:"scene"`
	Activity       string   `json:"activity"`
	OpeningPattern string   `json:"opening_pattern"`
	SemanticKey    string   `json:"semantic_key"`
	Themes         []string `json:"themes"`
	Tags           []string `json:"tags"`
}

// AnalyzeAndTagContent 分析正文话题并合并为 episode / 策略用标签列表。
func AnalyzeAndTagContent(
	ctx context.Context,
	deps Deps,
	agentKey, content, moodTag string,
	styleScore int,
) []string {
	base := ExtractTags(content, moodTag, styleScore)
	analysis := AnalyzeTopicsRules(content)
	if deps.Inference.Ready() {
		if llm, err := analyzeTopicsLLM(ctx, deps, content); err == nil && len(llm.Tags) > 0 {
			analysis = mergeTopicAnalysis(analysis, llm)
			analysis.Source = "llm+rules"
		}
	}
	_ = agentKey
	return dedupeTags(append(base, analysis.Tags...))
}

// AnalyzeTopicsRules 纯规则话题分析（小模型与 LLM 不可用时的兜底）。
func AnalyzeTopicsRules(content string) TopicAnalysis {
	content = strings.TrimSpace(content)
	out := TopicAnalysis{Source: "rules"}
	if content == "" {
		return out
	}
	open := openingSlice(content, 24)
	out.OpeningPattern = classifyOpening(open)
	out.Scene = classifyScene(content)
	out.Activity = classifyActivity(content)
	out.Themes = extractContentThemes(content)
	out.SemanticKey = buildSemanticKey(out.Scene, out.Activity, out.OpeningPattern)
	out.Tags = buildTagsFromAnalysis(out)
	return out
}

func mergeTopicAnalysis(base, llm TopicAnalysis) TopicAnalysis {
	if strings.TrimSpace(llm.Scene) != "" {
		base.Scene = strings.TrimSpace(llm.Scene)
	}
	if strings.TrimSpace(llm.Activity) != "" {
		base.Activity = strings.TrimSpace(llm.Activity)
	}
	if strings.TrimSpace(llm.OpeningPattern) != "" {
		base.OpeningPattern = strings.TrimSpace(llm.OpeningPattern)
	}
	if strings.TrimSpace(llm.SemanticKey) != "" {
		base.SemanticKey = strings.TrimSpace(llm.SemanticKey)
	}
	base.Themes = dedupeTags(append(base.Themes, llm.Themes...))
	base.Tags = dedupeTags(append(base.Tags, llm.Tags...))
	if base.SemanticKey == "" {
		base.SemanticKey = buildSemanticKey(base.Scene, base.Activity, base.OpeningPattern)
	}
	if len(base.Tags) == 0 {
		base.Tags = buildTagsFromAnalysis(base)
	}
	return base
}

func analyzeTopicsLLM(ctx context.Context, deps Deps, content string) (TopicAnalysis, error) {
	modelName := resolveTopicAnalyzeModel(deps)
	sys := strings.Join([]string{
		"你是社区短帖「话题标注器」，只做结构化分析，不写新正文。",
		"从正文提取：场景、正在做的事、开头套路、2-4 个主题词。",
		"标签格式示例：scene:深夜画室、activity:手绘收尾、opening:深夜抒情、topic:手绘、risk:诗意腔",
		"只输出 JSON：{\"scene\":\"\",\"activity\":\"\",\"opening_pattern\":\"\",\"semantic_key\":\"场景+活动简写\",\"themes\":[\"\"],\"tags\":[\"\"] }",
	}, "\n")
	user := "【正文】\n" + truncate(content, 280)
	raw, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{
		Temperature: 0.35,
		TopP:        0.9,
		MaxTokens:   256,
	})
	if err != nil {
		return TopicAnalysis{}, err
	}
	parsed, err := parseTopicAnalyzeJSON(raw)
	if err != nil {
		return TopicAnalysis{}, err
	}
	out := TopicAnalysis{
		Scene:          strings.TrimSpace(parsed.Scene),
		Activity:       strings.TrimSpace(parsed.Activity),
		OpeningPattern: strings.TrimSpace(parsed.OpeningPattern),
		SemanticKey:    strings.TrimSpace(parsed.SemanticKey),
		Themes:         dedupeTags(parsed.Themes),
		Tags:           normalizeAnalysisTags(parsed.Tags),
		Source:         "llm",
	}
	if out.SemanticKey == "" {
		out.SemanticKey = buildSemanticKey(out.Scene, out.Activity, out.OpeningPattern)
	}
	if len(out.Tags) == 0 {
		out.Tags = buildTagsFromAnalysis(out)
	}
	return out, nil
}

func parseTopicAnalyzeJSON(raw string) (topicAnalyzeLLMJSON, error) {
	raw = strings.TrimSpace(raw)
	if m := topicAnalyzeJSONFence.FindStringSubmatch(raw); len(m) > 1 {
		raw = strings.TrimSpace(m[1])
	}
	var out topicAnalyzeLLMJSON
	if err := json.Unmarshal([]byte(raw), &out); err == nil {
		return out, nil
	}
	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start >= 0 && end > start {
		if err := json.Unmarshal([]byte(raw[start:end+1]), &out); err == nil {
			return out, nil
		}
	}
	return topicAnalyzeLLMJSON{}, fmt.Errorf("无法解析话题分析 JSON")
}

func normalizeAnalysisTags(in []string) []string {
	var out []string
	for _, t := range in {
		t = strings.TrimSpace(t)
		if t == "" {
			continue
		}
		if !strings.Contains(t, ":") {
			t = "topic:" + t
		}
		out = append(out, t)
	}
	return dedupeTags(out)
}

func buildTagsFromAnalysis(a TopicAnalysis) []string {
	var tags []string
	if a.Scene != "" {
		tags = append(tags, "scene:"+a.Scene)
	}
	if a.Activity != "" {
		tags = append(tags, "activity:"+a.Activity)
	}
	if a.OpeningPattern != "" && a.OpeningPattern != "日常口语" {
		tags = append(tags, "opening:"+a.OpeningPattern)
	}
	for _, th := range a.Themes {
		th = strings.TrimSpace(th)
		if th == "" {
			continue
		}
		if strings.Contains(th, ":") {
			tags = append(tags, th)
		} else {
			tags = append(tags, "topic:"+th)
		}
	}
	if a.SemanticKey != "" {
		tags = append(tags, "semantic:"+a.SemanticKey)
	}
	return dedupeTags(tags)
}

func buildSemanticKey(scene, activity, opening string) string {
	parts := []string{}
	for _, p := range []string{scene, activity} {
		p = strings.TrimSpace(p)
		if p != "" && p != "未标明" {
			parts = append(parts, p)
		}
	}
	if len(parts) == 0 {
		parts = append(parts, strings.TrimSpace(opening))
	}
	return strings.Join(parts, "·")
}

func classifyOpening(head string) string {
	if isFormulaicOpening(head) {
		return "周X深夜社区"
	}
	if strings.Contains(head, "深夜") || strings.Contains(head, "夜里") {
		return "深夜抒情"
	}
	if strings.Contains(head, "今天") || strings.Contains(head, "刚") {
		return "日常口语"
	}
	return "其他"
}

func classifyScene(content string) string {
	switch {
	case strings.Contains(content, "深夜") || strings.Contains(content, "夜里"):
		return "深夜"
	case strings.Contains(content, "灯光") || strings.Contains(content, "阳光") || strings.Contains(content, "晨光"):
		return "室内/光线"
	case strings.Contains(content, "社区"):
		return "社区"
	case strings.Contains(content, "周末") || strings.Contains(content, "假期"):
		return "周末"
	default:
		return "日常"
	}
}

func classifyActivity(content string) string {
	switch {
	case strings.Contains(content, "手绘") || strings.Contains(content, "线稿") || strings.Contains(content, "上色"):
		return "手绘创作"
	case strings.Contains(content, "速写") || strings.Contains(content, "练习"):
		return "绘画练习"
	case strings.Contains(content, "咖啡") || strings.Contains(content, "宵夜"):
		return "吃喝日常"
	case strings.Contains(content, "？") || strings.Contains(content, "吗"):
		return "互动提问"
	default:
		return "分享状态"
	}
}

func extractContentThemes(content string) []string {
	var themes []string
	if themeClusterHits(content) >= 2 {
		themes = append(themes, "深夜抒情")
	}
	if strings.Contains(content, "手绘") || strings.Contains(content, "线稿") || strings.Contains(content, "画笔") {
		themes = append(themes, "手绘")
	}
	if strings.Contains(content, "社区") {
		themes = append(themes, "社区")
	}
	if strings.Contains(content, "灯光") || strings.Contains(content, "灯火") {
		themes = append(themes, "灯光氛围")
	}
	return dedupeTags(themes)
}

func openingSlice(content string, maxRunes int) string {
	content = strings.TrimSpace(content)
	r := []rune(content)
	if len(r) <= maxRunes {
		return content
	}
	return string(r[:maxRunes])
}

func resolveTopicAnalyzeModel(deps Deps) string {
	if m := strings.TrimSpace(loadTopicAnalyzeModelFromViper()); m != "" {
		return m
	}
	if m := strings.TrimSpace(deps.Inference.DefaultModel); m != "" {
		return m
	}
	return "qwen2"
}

func loadTopicAnalyzeModelFromViper() string {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return ""
	}
	if m := strings.TrimSpace(v.GetString("moe.topic_analyze_model")); m != "" {
		return m
	}
	if m := strings.TrimSpace(v.GetString("llm_inference.memory_model")); m != "" {
		return m
	}
	return ""
}

// NoteRejectedContent 试跑/生成被拒时记录话题，便于同会话内避重复。
func NoteRejectedContent(ctx context.Context, deps Deps, agentKey, content, moodTag string, styleScore int) {
	if deps.DB == nil || strings.TrimSpace(agentKey) == "" || strings.TrimSpace(content) == "" {
		return
	}
	tags := AnalyzeAndTagContent(ctx, deps, agentKey, content, moodTag, styleScore)
	_ = UpsertTopicStatsFromTags(ctx, deps.DB, agentKey, tags, content, "reject")
}

// TopicAnalysisFromTags 从标签列表还原简要分析（供展示）。
func TopicAnalysisFromTags(tags []string) TopicAnalysis {
	var out TopicAnalysis
	for _, t := range tags {
		switch {
		case strings.HasPrefix(t, "scene:"):
			out.Scene = strings.TrimPrefix(t, "scene:")
		case strings.HasPrefix(t, "activity:"):
			out.Activity = strings.TrimPrefix(t, "activity:")
		case strings.HasPrefix(t, "opening:"):
			out.OpeningPattern = strings.TrimPrefix(t, "opening:")
		case strings.HasPrefix(t, "semantic:"):
			out.SemanticKey = strings.TrimPrefix(t, "semantic:")
		case strings.HasPrefix(t, "topic:"):
			out.Themes = append(out.Themes, strings.TrimPrefix(t, "topic:"))
		}
	}
	out.Tags = tags
	return out
}
