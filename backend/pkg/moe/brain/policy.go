package brain

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// PolicyBlock 注入 LLM 的标签策略文本。
func PolicyBlock(rt model.MoeAgentRuntime, recent []model.MoeBotEpisode, db *gorm.DB) string {
	forbidden := ParseTagList(rt.ForbiddenTags)
	preferred := ParseTagList(rt.PreferredTags)
	if len(forbidden) == 0 {
		forbidden = []string{"risk:诗意腔", "tone:官方", "type:套路开场"}
	}
	stats := tagFrequency(recent, 30)
	var overused []string
	for tag, cnt := range stats {
		th := 3
		if strings.HasPrefix(tag, "type:") || strings.HasPrefix(tag, "tone:") || strings.HasPrefix(tag, "mood:") {
			th = 2
		}
		if strings.HasPrefix(tag, "scene:") || strings.HasPrefix(tag, "activity:") || strings.HasPrefix(tag, "semantic:") {
			th = 2
		}
		if cnt >= th {
			overused = append(overused, fmt.Sprintf("%s(已用%d次)", tag, cnt))
		}
	}
	sort.Strings(overused)

	lines := []string{"【AI 大脑 · 标签策略】"}
	if len(forbidden) > 0 {
		lines = append(lines, "禁止生成带有以下标签的内容："+strings.Join(forbidden, "、"))
	}
	if len(preferred) > 0 {
		lines = append(lines, "优先使用以下标签方向："+strings.Join(preferred, "、"))
	}
	locked := LockedSkillsFromRuntime(rt)
	if len(locked) > 0 {
		lines = append(lines, "【记忆 RPG · 已锁定技能】发帖时必须体现："+strings.Join(locked, "、"))
	}
	if len(overused) > 0 {
		lines = append(lines, "近期已过多，请换角度："+strings.Join(overused, "、"))
	}
	if db != nil {
		lines = append(lines, "", BuildTopicDiversityBlock(rt, recent, db))
	}
	return strings.Join(lines, "\n")
}

func tagFrequency(episodes []model.MoeBotEpisode, limit int) map[string]int {
	out := make(map[string]int)
	n := 0
	for _, ep := range episodes {
		if n >= limit {
			break
		}
		n++
		for _, t := range parseTagsJSON(ep.TagsJSON) {
			out[t]++
		}
	}
	return out
}

func parseTagsJSON(raw string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var tags []string
	if json.Unmarshal([]byte(raw), &tags) == nil {
		return tags
	}
	return nil
}

// EpisodeTagsViolate 生成内容是否违反禁止标签（基于规则标签复检）。
func EpisodeTagsViolate(content, moodTag string, styleScore int, forbidden []string) []string {
	tags := ExtractTags(content, moodTag, styleScore)
	return TagsConflict(tags, forbidden)
}
