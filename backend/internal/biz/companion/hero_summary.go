package companionbiz

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	lifebiz "backend/internal/biz/life"
	"backend/model"
)

const (
	// heroSystemMemoryType 机器行记忆（水位线等），永不注入聊天上下文。
	heroSystemMemoryType = "system"
	// heroSummaryWatermarkKey 离线摘要水位线 memory_key，content 存 RFC3339 时间戳。
	heroSummaryWatermarkKey = "offline_summary_watermark"
	// heroSummaryMinOffline 离线不足该时长不生成摘要。
	heroSummaryMinOffline = 2 * time.Hour
	// heroSummaryDefaultWindow 首次（无水位线）回看窗口。
	heroSummaryDefaultWindow = 24 * time.Hour
	// heroSummaryMaxNarrated 摘要正文最多叙述的事件条数。
	heroSummaryMaxNarrated = 3
	// heroSummaryEventScanLimit 一次扫描的世界事件上限。
	heroSummaryEventScanLimit = 50
	// heroSummaryMemoryScanLimit 读 per-hero 记忆找水位线的条数上限。
	heroSummaryMemoryScanLimit = 50
)

// HeroSummary O4 登录快进摘要（规则模板版，不走 LLM）。
type HeroSummary struct {
	Text         string
	OfflineHours int
	EventCount   int
}

// HeroOfflineSummary 生成「你不在的 N 小时里」离线摘要。
// 摘要写入 per-hero 记忆命名空间（注入后续聊天上下文），水位线随之前移；
// 离线不足阈值或窗口内无事件时返回 nil。
func (e *Engine) HeroOfflineSummary(
	ctx context.Context,
	userID uint,
	heroSlug string,
	now time.Time,
) (*HeroSummary, error) {
	hero, ok := lifebiz.HeroForSlug(heroSlug)
	if !ok {
		return nil, fmt.Errorf("hero summary slug %q: %w", heroSlug, ErrHeroNotFound)
	}
	if e.lifeStore == nil {
		return nil, nil
	}
	entities, err := e.lifeStore.ListEntities(ctx, "default")
	if err != nil {
		return nil, fmt.Errorf("hero summary list life entities: %w", err)
	}
	var entity *model.LifeEntity
	for i := range entities {
		if entities[i].HeroSlug == heroSlug {
			entity = &entities[i]
			break
		}
	}
	if entity == nil {
		return nil, nil
	}

	memories, err := e.store.ListActiveHeroMemories(ctx, userID, heroSlug, heroSummaryMemoryScanLimit)
	if err != nil {
		return nil, fmt.Errorf("hero summary list memories for user %d: %w", userID, err)
	}
	var watermark *model.CompanionMemory
	windowStart := now.Add(-heroSummaryDefaultWindow)
	for i := range memories {
		if memories[i].MemoryType == heroSystemMemoryType && memories[i].MemoryKey == heroSummaryWatermarkKey {
			row := memories[i]
			if parsed, parseErr := time.Parse(time.RFC3339, strings.TrimSpace(row.Content)); parseErr == nil {
				windowStart = parsed
				watermark = &row
			}
			break
		}
	}
	if now.Sub(windowStart) < heroSummaryMinOffline {
		return nil, nil
	}

	logs, err := e.lifeStore.ListRecentEventLogsByEntity(ctx, "default", entity.ID, heroSummaryEventScanLimit)
	if err != nil {
		return nil, fmt.Errorf("hero summary list world events for entity %d: %w", entity.ID, err)
	}
	events := make([]model.LifeEventLog, 0, len(logs))
	for _, entry := range logs {
		if entry.EventType == "idle" {
			continue
		}
		description := strings.TrimSpace(entry.Description)
		if description == "" {
			continue
		}
		if entry.CreatedAt.After(windowStart) && !entry.CreatedAt.After(now) {
			events = append(events, entry)
		}
	}
	sort.Slice(events, func(i, j int) bool { return events[i].CreatedAt.Before(events[j].CreatedAt) })

	if len(events) == 0 {
		// 窗口内无事件：水位线前移避免重复扫描，但不产生摘要。
		if err := e.upsertHeroSummaryWatermark(ctx, userID, heroSlug, watermark, now); err != nil {
			return nil, err
		}
		return nil, nil
	}

	summary := &HeroSummary{
		Text:         buildHeroSummaryText(hero.Name, windowStart, now, events),
		OfflineHours: int(now.Sub(windowStart).Hours()),
		EventCount:   len(events),
	}
	summaryMemory := &model.CompanionMemory{
		UserID:     userID,
		HeroID:     heroSlug,
		MemoryType: "fact",
		MemoryKey:  "offline_summary:" + now.UTC().Format("20060102T150405Z"),
		Content:    summary.Text,
		Importance: 0,
		ExpiresAt:  memoryExpiresAt(0),
	}
	if err := e.store.CreateMemory(ctx, summaryMemory); err != nil {
		return nil, fmt.Errorf("hero summary persist memory for user %d: %w", userID, err)
	}
	if err := e.upsertHeroSummaryWatermark(ctx, userID, heroSlug, watermark, now); err != nil {
		return nil, err
	}
	return summary, nil
}

// upsertHeroSummaryWatermark 前移摘要水位线（永久记忆，system 类型不入聊天上下文）。
func (e *Engine) upsertHeroSummaryWatermark(
	ctx context.Context,
	userID uint,
	heroSlug string,
	existing *model.CompanionMemory,
	now time.Time,
) error {
	content := now.UTC().Format(time.RFC3339)
	if existing != nil {
		if err := e.store.UpdateMemoryRecord(
			ctx, userID, existing.ID,
			heroSystemMemoryType, heroSummaryWatermarkKey, content,
			2, nil, 1.0,
		); err != nil {
			return fmt.Errorf("hero summary move watermark for user %d: %w", userID, err)
		}
		return nil
	}
	watermark := &model.CompanionMemory{
		UserID:     userID,
		HeroID:     heroSlug,
		MemoryType: heroSystemMemoryType,
		MemoryKey:  heroSummaryWatermarkKey,
		Content:    content,
		Importance: 2,
		Confidence: 1.0,
	}
	if err := e.store.CreateMemory(ctx, watermark); err != nil {
		return fmt.Errorf("hero summary create watermark for user %d: %w", userID, err)
	}
	return nil
}

// buildHeroSummaryText 规则模板拼装：最近几条事件按时间序叙述，余量折叠计数。
func buildHeroSummaryText(
	heroName string,
	windowStart time.Time,
	now time.Time,
	events []model.LifeEventLog,
) string {
	hours := int(now.Sub(windowStart).Hours())
	if hours < 1 {
		hours = 1
	}
	narrated := events
	if len(narrated) > heroSummaryMaxNarrated {
		narrated = narrated[len(narrated)-heroSummaryMaxNarrated:]
	}
	descriptions := make([]string, 0, len(narrated))
	for _, event := range narrated {
		descriptions = append(descriptions, strings.TrimSpace(event.Description))
	}
	var b strings.Builder
	fmt.Fprintf(&b, "你不在的 %d 小时里，%s", hours, heroName)
	b.WriteString(strings.Join(descriptions, "，"))
	if extra := len(events) - len(narrated); extra > 0 {
		fmt.Fprintf(&b, "，还经历了 %d 件小事", extra)
	}
	b.WriteString("。")
	return b.String()
}
