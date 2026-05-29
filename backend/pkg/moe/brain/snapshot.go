package brain

import (
	"context"
	"encoding/json"
	"sort"
	"strconv"
	"strings"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// Snapshot 管理端 AI 大脑视图。
type Snapshot struct {
	AgentKey       string
	DisplayName    string
	BotUserID      uint
	ForbiddenTags  []string
	PreferredTags  []string
	TagStats       []TagStat
	Episodes       []EpisodeItem
	Memories       []MemoryItem
	GenerationMeta GenerationMeta
	StabilityScore int
	StabilityDelta int
}

type TagStat struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

type EpisodeItem struct {
	ID            uint     `json:"id"`
	PostID        string   `json:"post_id"`
	Content       string   `json:"content"`
	Tags          []string `json:"tags"`
	MoodTag       string   `json:"mood_tag"`
	StyleScore    int      `json:"style_score"`
	QualityScore  int      `json:"quality_score"`
	Approved      bool     `json:"approved"`
	RevisionCount int      `json:"revision_count"`
	MemoryKey     string   `json:"memory_key"`
	Source        string   `json:"source"`
	CreatedAt     string   `json:"created_at"`
}

type MemoryItem struct {
	Key        string `json:"key"`
	Value      string `json:"value"`
	MemoryType string `json:"memory_type"`
	UpdatedAt  string `json:"updated_at"`
}

// LoadSnapshot 拉取 Bot 大脑数据。
func LoadSnapshot(ctx context.Context, db *gorm.DB, rpc port.MoeToolPort, agentKey string) (*Snapshot, error) {
	agentKey = strings.TrimSpace(agentKey)
	var rt model.MoeAgentRuntime
	if err := db.Where("agent_key = ?", agentKey).First(&rt).Error; err != nil {
		return nil, err
	}
	var episodes []model.MoeBotEpisode
	_ = db.Where("agent_key = ?", agentKey).Order("created_at desc").Limit(50).Find(&episodes).Error

	stats := tagFrequency(episodes, 50)
	tagStats := make([]TagStat, 0, len(stats))
	for t, c := range stats {
		tagStats = append(tagStats, TagStat{Tag: t, Count: c})
	}
	sort.Slice(tagStats, func(i, j int) bool {
		if tagStats[i].Count == tagStats[j].Count {
			return tagStats[i].Tag < tagStats[j].Tag
		}
		return tagStats[i].Count > tagStats[j].Count
	})

	items := make([]EpisodeItem, 0, len(episodes))
	forbidden := ParseTagList(rt.ForbiddenTags)
	for _, ep := range episodes {
		tags := parseTagsJSON(ep.TagsJSON)
		q := EffectiveQuality(ep, forbidden)
		approved := ep.Approved
		if !approved {
			approved = IsApprovedQuality(q) && !NeedsRefinement(q, tags, forbidden)
		}
		items = append(items, EpisodeItem{
			ID:            ep.ID,
			PostID:        ep.PostID,
			Content:       ep.Content,
			Tags:          parseTagsJSON(ep.TagsJSON),
			MoodTag:       ep.MoodTag,
			StyleScore:    ep.StyleScore,
			QualityScore:  q,
			Approved:      approved,
			RevisionCount: ep.RevisionCount,
			MemoryKey:     ep.MemoryKey,
			Source:        ep.Source,
			CreatedAt:     ep.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	memories := []MemoryItem{}
	if rpc != nil && rt.BotUserID > 0 {
		uid := strconv.FormatUint(uint64(rt.BotUserID), 10)
		resp, err := rpc.GetUserMemories(ctx, &moe.GetUserMemoriesReq{UserId: uid})
		if err == nil && resp != nil {
			records := memory.RecordsFromSuper(resp.Memories)
			for _, rec := range records {
				if !strings.HasPrefix(rec.Key, "bot_post:") && rec.MemoryType != "bot_episode" {
					continue
				}
				memories = append(memories, MemoryItem{
					Key:        rec.Key,
					Value:      rec.Value,
					MemoryType: rec.MemoryType,
					UpdatedAt:  rec.UpdatedAt.Format("2006-01-02 15:04:05"),
				})
			}
		}
	}

	stability := EffectiveStabilityScore(rt)
	stabilityDelta := lastRunStabilityDelta(db, agentKey)

	return &Snapshot{
		AgentKey:       rt.AgentKey,
		DisplayName:    rt.DisplayName,
		BotUserID:      rt.BotUserID,
		ForbiddenTags:  ParseTagList(rt.ForbiddenTags),
		PreferredTags:  ParseTagList(rt.PreferredTags),
		TagStats:       tagStats,
		Episodes:       items,
		Memories:       memories,
		GenerationMeta: BuildGenerationMeta(ctx, db, rpc, rt, len(memories)),
		StabilityScore: stability,
		StabilityDelta: stabilityDelta,
	}, nil
}

// UpdatePolicy 更新标签策略。
func UpdatePolicy(db *gorm.DB, agentKey string, forbidden, preferred []string) error {
	return db.Model(&model.MoeAgentRuntime{}).Where("agent_key = ?", agentKey).Updates(map[string]any{
		"forbidden_tags": strings.Join(forbidden, "\n"),
		"preferred_tags": strings.Join(preferred, "\n"),
	}).Error
}

func lastRunStabilityDelta(db *gorm.DB, agentKey string) int {
	if db == nil {
		return 0
	}
	var row model.MoeAgentRunLog
	err := db.Where("agent_key = ?", strings.TrimSpace(agentKey)).
		Order("created_at desc").
		First(&row).Error
	if err != nil {
		return 0
	}
	raw := strings.TrimSpace(row.StepsJSON)
	if raw == "" || !strings.HasPrefix(raw, "{") {
		return 0
	}
	var bundle struct {
		StabilityDelta int `json:"stability_delta"`
	}
	if json.Unmarshal([]byte(raw), &bundle) != nil {
		return 0
	}
	return bundle.StabilityDelta
}

// ListRecentEpisodes 供生成时读取。
func ListRecentEpisodes(db *gorm.DB, agentKey string, limit int) []model.MoeBotEpisode {
	var rows []model.MoeBotEpisode
	_ = db.Where("agent_key = ?", agentKey).Order("created_at desc").Limit(limit).Find(&rows).Error
	return rows
}
