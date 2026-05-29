package brain

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// Deps 大脑写入依赖。
type Deps struct {
	DB        *gorm.DB
	RPC       port.MoeToolPort
	Inference llminference.Config
}

// RecordInput 发帖成功后记录自传。
type RecordInput struct {
	AgentKey   string
	BotUserID  uint
	PostID     string
	Content    string
	MoodTag    string
	StyleScore int
	Source     string
}

// RecordEpisode 写入 episode 表 + user_memories（自己说过的话）。
func RecordEpisode(ctx context.Context, deps Deps, in RecordInput) error {
	if deps.DB == nil || strings.TrimSpace(in.PostID) == "" {
		return fmt.Errorf("brain: db or post_id missing")
	}
	tags := AnalyzeAndTagContent(ctx, deps, in.AgentKey, in.Content, in.MoodTag, in.StyleScore)
	tagsJSON, _ := json.Marshal(tags)
	_ = UpsertTopicStatsFromTags(ctx, deps.DB, in.AgentKey, tags, in.Content, "episode")
	memKey := fmt.Sprintf("bot_post:%s", strings.TrimSpace(in.PostID))
	src := strings.TrimSpace(in.Source)
	if src == "" {
		src = "runtime"
	}

	var rt model.MoeAgentRuntime
	forbidden := []string{}
	if deps.DB != nil && strings.TrimSpace(in.AgentKey) != "" {
		if err := deps.DB.Where("agent_key = ?", in.AgentKey).First(&rt).Error; err == nil {
			forbidden = ParseTagList(rt.ForbiddenTags)
		}
	}
	quality := ComputeQualityScore(in.Content, in.MoodTag, in.StyleScore, forbidden)
	approved := IsApprovedQuality(quality) && !NeedsRefinement(quality, tags, forbidden)

	ep := model.MoeBotEpisode{
		AgentKey:      strings.TrimSpace(in.AgentKey),
		BotUserID:     in.BotUserID,
		PostID:        in.PostID,
		Content:       strings.TrimSpace(in.Content),
		TagsJSON:      string(tagsJSON),
		MoodTag:       in.MoodTag,
		StyleScore:    in.StyleScore,
		QualityScore:  quality,
		Approved:      approved,
		RevisionCount: 0,
		MemoryKey:     memKey,
		Source:        src,
	}
	if err := deps.DB.Create(&ep).Error; err != nil {
		return err
	}

	if deps.RPC != nil && in.BotUserID > 0 {
		val := fmt.Sprintf("%s\n标签: %s\n质量: %d", truncate(in.Content, 200), strings.Join(tags, ", "), quality)
		_, _ = deps.RPC.UpsertUserMemory(ctx, &moe.UpsertUserMemoryReq{
			UserId:     strconv.FormatUint(uint64(in.BotUserID), 10),
			Key:        memKey,
			Value:      val,
			MemoryType: "bot_episode",
			Source:     "moe_bot_brain",
			Confidence: float64(quality) / 100.0,
		})
	}
	return nil
}

// DeleteEpisode 删除自传记录并尝试删对应记忆 key。
func DeleteEpisode(ctx context.Context, deps Deps, episodeID uint) error {
	if deps.DB == nil {
		return fmt.Errorf("brain: db nil")
	}
	var ep model.MoeBotEpisode
	if err := deps.DB.First(&ep, episodeID).Error; err != nil {
		return err
	}
	if err := deps.DB.Delete(&ep).Error; err != nil {
		return err
	}
	if deps.RPC != nil && ep.MemoryKey != "" && ep.BotUserID > 0 {
		_, _ = deps.RPC.DeleteUserMemory(ctx, &moe.DeleteUserMemoryReq{
			UserId: strconv.FormatUint(uint64(ep.BotUserID), 10),
			Key:    ep.MemoryKey,
		})
	}
	return nil
}

func truncate(s string, max int) string {
	s = strings.TrimSpace(s)
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max]) + "…"
}
