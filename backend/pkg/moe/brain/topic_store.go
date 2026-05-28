package brain

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

const topicOveruseThreshold = 3

// UpsertTopicStatsFromTags 将分析标签写入 agent 话题统计表。
func UpsertTopicStatsFromTags(ctx context.Context, db *gorm.DB, agentKey string, tags []string, snippet, source string) error {
	if db == nil || strings.TrimSpace(agentKey) == "" {
		return nil
	}
	_ = ctx
	keys := topicKeysFromTags(tags)
	if len(keys) == 0 {
		return nil
	}
	snippet = truncate(strings.TrimSpace(snippet), 120)
	now := time.Now()
	for _, k := range keys {
		label := k.label
		if label == "" {
			label = k.key
		}
		var row model.MoeAgentTopicStat
		err := db.Where("agent_key = ? AND topic_key = ?", agentKey, k.key).First(&row).Error
		if err == gorm.ErrRecordNotFound {
			row = model.MoeAgentTopicStat{
				AgentKey:      agentKey,
				TopicKey:      k.key,
				Label:         label,
				UseCount:      1,
				SampleSnippet: snippet,
				Source:        source,
				LastUsedAt:    now,
			}
			if err := db.Create(&row).Error; err != nil {
				return err
			}
			continue
		}
		if err != nil {
			return err
		}
		row.UseCount++
		row.LastUsedAt = now
		if snippet != "" {
			row.SampleSnippet = snippet
		}
		if source != "" {
			row.Source = source
		}
		if err := db.Save(&row).Error; err != nil {
			return err
		}
	}
	return nil
}

type topicKeyLabel struct {
	key   string
	label string
}

func topicKeysFromTags(tags []string) []topicKeyLabel {
	seen := make(map[string]bool)
	var out []topicKeyLabel
	for _, t := range tags {
		t = strings.TrimSpace(t)
		if t == "" {
			continue
		}
		var key, label string
		switch {
		case strings.HasPrefix(t, "semantic:"):
			key = t
			label = strings.TrimPrefix(t, "semantic:")
		case strings.HasPrefix(t, "scene:"):
			key = t
			label = "场景·" + strings.TrimPrefix(t, "scene:")
		case strings.HasPrefix(t, "activity:"):
			key = t
			label = "活动·" + strings.TrimPrefix(t, "activity:")
		case strings.HasPrefix(t, "opening:"):
			key = t
			label = "开头·" + strings.TrimPrefix(t, "opening:")
		case strings.HasPrefix(t, "topic:"):
			key = t
			label = strings.TrimPrefix(t, "topic:")
		default:
			continue
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, topicKeyLabel{key: key, label: label})
	}
	return out
}

// ListOverusedTopics 返回近期使用过多、生成时应避开的话题。
func ListOverusedTopics(db *gorm.DB, agentKey string, minCount int, limit int) []model.MoeAgentTopicStat {
	if db == nil || strings.TrimSpace(agentKey) == "" {
		return nil
	}
	if minCount <= 0 {
		minCount = topicOveruseThreshold
	}
	if limit <= 0 {
		limit = 12
	}
	var rows []model.MoeAgentTopicStat
	_ = db.Where("agent_key = ? AND use_count >= ?", agentKey, minCount).
		Order("use_count desc, last_used_at desc").
		Limit(limit).
		Find(&rows).Error
	return rows
}

// BuildTopicDiversityBlock 注入发帖 prompt：基于 DB 话题统计 + episode 标签频率。
func BuildTopicDiversityBlock(rt model.MoeAgentRuntime, episodes []model.MoeBotEpisode, db *gorm.DB) string {
	var lines []string
	lines = append(lines, "【话题智能 · 避模板】")
	lines = append(lines, "- 系统已分析你近期发帖的话题/场景，请勿复读同一套路")

	overused := ListOverusedTopics(db, rt.AgentKey, topicOveruseThreshold, 10)
	if len(overused) > 0 {
		parts := make([]string, 0, len(overused))
		for _, row := range overused {
			parts = append(parts, fmt.Sprintf("%s(×%d)", row.Label, row.UseCount))
		}
		lines = append(lines, "数据库统计·近期过多："+strings.Join(parts, "、"))
	}

	stats := tagFrequency(episodes, 24)
	var freqParts []string
	for tag, cnt := range stats {
		th := 3
		if strings.HasPrefix(tag, "scene:") || strings.HasPrefix(tag, "activity:") || strings.HasPrefix(tag, "semantic:") {
			th = 2
		}
		if cnt >= th {
			freqParts = append(freqParts, fmt.Sprintf("%s(×%d)", tag, cnt))
		}
	}
	sort.Strings(freqParts)
	if len(freqParts) > 0 {
		lines = append(lines, "自传标签·近期过多："+strings.Join(freqParts, "、"))
	}

	suggestions := suggestFreshAngles(overused, freqParts)
	if len(suggestions) > 0 {
		lines = append(lines, "本次可尝试："+strings.Join(suggestions, "、"))
	}
	return strings.Join(lines, "\n")
}

func suggestFreshAngles(dbOverused []model.MoeAgentTopicStat, tagOverused []string) []string {
	used := make(map[string]bool)
	for _, row := range dbOverused {
		used[strings.ToLower(row.Label)] = true
	}
	for _, p := range tagOverused {
		used[strings.ToLower(p)] = true
	}
	candidates := []string{
		"画材翻车/买错笔", "具体数字进度", "排队买咖啡", "宵夜选择",
		"周末计划吐槽", "工具推荐提问", "天气影响创作",
	}
	var out []string
	for _, c := range candidates {
		skip := false
		lower := strings.ToLower(c)
		for u := range used {
			if strings.Contains(lower, u) || strings.Contains(u, lower) {
				skip = true
				break
			}
		}
		if !skip {
			out = append(out, c)
		}
		if len(out) >= 3 {
			break
		}
	}
	return out
}
