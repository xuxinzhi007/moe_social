package companionbiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"sort"
	"strings"
	"sync"
	"time"

	"backend/model"
	"backend/pkg/llminference"

	"gorm.io/gorm"
)

// Engine Companion 核心引擎：整合 Profile / State / Memory / Chat / LLM。
type Engine struct {
	store     Store
	lifeStore LifeStore // 读取 LifeEntity 状态（可为 nil）
	llmCfg    llminference.Config
	model     string

	// 配置参数
	MaxHistoryTurns int           // 聊天历史注入条数，默认 10
	MaxMemories     int           // 记忆注入条数，默认 5
	CleanupInterval time.Duration // 记忆清理周期，默认 1h

	// WebSocket 广播回调（可选，nil 时不广播）
	OnGreeting  func(userID uint, greeting string)
	OnProactive func(userID uint, message, reason string) (notificationID uint, delivered bool)
	OnEvent     func(userID uint, event *model.CompanionEvent)

	// 内部
	cancelCleanup  context.CancelFunc
	cancelGreeting context.CancelFunc
	proactiveMu    sync.Mutex
	lastProactive  map[uint]proactiveDelivery
}

type proactiveDelivery struct {
	localDate string
	count     int
}

// ChatStream sends one message with an optional per-request inference config.
type ChatInferenceOverride = llminference.Config

// NewEngine 创建 Companion 引擎。lifeStore 可为 nil（无数字生命数据时退化）。
func NewEngine(store Store, lifeStore LifeStore, llmCfg llminference.Config, model string) *Engine {
	return &Engine{
		store:           store,
		lifeStore:       lifeStore,
		llmCfg:          llmCfg,
		model:           model,
		MaxHistoryTurns: 10,
		MaxMemories:     5,
		CleanupInterval: time.Hour,
		lastProactive:   make(map[uint]proactiveDelivery),
	}
}

// StartGreetingTicker 启动定时问候广播（每隔一段时间推送伙伴状态变化）。
func (e *Engine) StartGreetingTicker(ctx context.Context) {
	if e.cancelGreeting != nil {
		return
	}
	ctx, cancel := context.WithCancel(ctx)
	e.cancelGreeting = cancel
	go e.greetingLoop(ctx)
}

// StopGreetingTicker 停止问候广播。
func (e *Engine) StopGreetingTicker() {
	if e.cancelGreeting != nil {
		e.cancelGreeting()
		e.cancelGreeting = nil
	}
}

func (e *Engine) greetingLoop(ctx context.Context) {
	// 延迟 30s 后开始第一次问候
	select {
	case <-ctx.Done():
		return
	case <-time.After(30 * time.Second):
	}

	e.pushGreeting()

	// 每 5 分钟推送一次状态变化
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			e.pushGreeting()
		}
	}
}

func (e *Engine) pushGreeting() {
	if e.OnGreeting == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	userIDs, err := e.store.ListProfileUserIDs(ctx)
	if err != nil {
		log.Printf("[companion] list greeting users: %v", err)
		return
	}
	for _, userID := range userIDs {
		state, _, err := e.GetState(ctx, userID)
		if err != nil || state == nil {
			continue
		}
		e.OnGreeting(userID, state.Greeting)
		e.pushProactive(userID)
	}
}

func (e *Engine) pushProactive(userID uint) {
	if e.OnProactive == nil {
		return
	}
	companionContext, err := e.BuildContext(context.Background(), userID, "proactive")
	if err != nil || companionContext == nil || companionContext.Profile == nil || !companionContext.Profile.ProactiveEnabled {
		return
	}
	profile := companionContext.Profile
	now := time.Now().UTC().Add(time.Duration(profile.ProactiveTimezoneOffset) * time.Minute)
	minuteOfDay := now.Hour()*60 + now.Minute()
	if inQuietHours(minuteOfDay, profile.ProactiveQuietStart, profile.ProactiveQuietEnd) {
		return
	}
	history := companionContext.History
	if len(history) == 0 {
		return
	}
	last := history[len(history)-1]
	if last.CreatedAt.IsZero() || time.Since(last.CreatedAt) < 24*time.Hour {
		return
	}
	pendingDeliveryKey := ""
	if deliveries, listErr := e.ListProactiveDeliveries(context.Background(), userID, 100); listErr != nil {
		log.Printf("[companion] list pending proactive deliveries user=%d: %v", userID, listErr)
	} else {
		for _, delivery := range deliveries {
			if delivery.Status != "scheduled" || delivery.DeliveryKey == "" {
				continue
			}
			if delivery.ExpiresAt != nil && time.Now().UTC().After(*delivery.ExpiresAt) {
				continue
			}
			pendingDeliveryKey = delivery.DeliveryKey
			break
		}
	}

	e.proactiveMu.Lock()
	reserved := false
	localDate := now.Format("2006-01-02")
	persistedCount, persistedErr := e.countProactiveDeliveries(
		context.Background(), userID, localDate, profile.ProactiveTimezoneOffset,
	)
	if persistedErr != nil {
		log.Printf("[companion] count proactive deliveries user=%d: %v", userID, persistedErr)
	}
	delivery := e.lastProactive[userID]
	if delivery.localDate != localDate {
		delivery.count = persistedCount
	} else if delivery.count < persistedCount {
		delivery.count = persistedCount
	}
	deliveryKey := pendingDeliveryKey
	if deliveryKey == "" {
		dailyLimit := profile.ProactiveDailyLimit
		if dailyLimit <= 0 {
			dailyLimit = 1
		}
		if delivery.count >= dailyLimit {
			e.proactiveMu.Unlock()
			return
		}
		delivery.localDate = localDate
		delivery.count++
		reserved = true
		deliveryKey = fmt.Sprintf("proactive:%d:%s:%d:%d", userID, localDate, delivery.count, time.Now().UnixNano())
	} else {
		delivery.localDate = localDate
	}
	e.lastProactive[userID] = delivery
	e.proactiveMu.Unlock()

	message := "有一阵子没见到你了，最近过得怎么样？"
	if len(companionContext.UnfinishedTopics) > 0 {
		message = fmt.Sprintf("我还记得你想继续的话题：『%s』，最近有新进展吗？", companionContext.UnfinishedTopics[0])
	} else {
		for index := len(history) - 1; index >= 0; index-- {
			if history[index].Role == "user" && strings.TrimSpace(history[index].Content) != "" {
				message = fmt.Sprintf("我还记得你之前提到的「%s」，最近有新进展吗？", clipProactiveText(history[index].Content))
				break
			}
		}
	}
	reason := "久未聊天回访"
	priority := 50
	expiresAt := time.Now().UTC().Add(72 * time.Hour)
	e.recordCompanionEvent(context.Background(), userID, "proactive_scheduled", "proactive", 0,
		deliveryKey, map[string]interface{}{
			"reason":     reason,
			"priority":   priority,
			"expires_at": expiresAt.Format(time.RFC3339),
		})
	notificationID, delivered := e.OnProactive(userID, message, reason)
	if !delivered {
		if reserved {
			e.proactiveMu.Lock()
			current := e.lastProactive[userID]
			if current.localDate == localDate && current.count > 0 {
				current.count--
				e.lastProactive[userID] = current
			}
			e.proactiveMu.Unlock()
		}
		e.recordCompanionEvent(context.Background(), userID, "proactive_delivery_failed", "proactive", notificationID,
			deliveryKey+":failed", map[string]interface{}{
				"reason":          reason,
				"priority":        priority,
				"notification_id": notificationID,
				"expires_at":      expiresAt.Format(time.RFC3339),
			})
		return
	}
	e.recordCompanionEvent(context.Background(), userID, "proactive_delivered", "proactive", notificationID,
		deliveryKey+":delivered", map[string]interface{}{
			"reason":          reason,
			"priority":        priority,
			"notification_id": notificationID,
			"expires_at":      expiresAt.Format(time.RFC3339),
		})
}

func (e *Engine) countProactiveDeliveries(
	ctx context.Context,
	userID uint,
	localDate string,
	timezoneOffset int,
) (int, error) {
	events, err := e.store.ListCompanionEvents(ctx, userID, 100)
	if err != nil {
		return 0, err
	}
	count := 0
	for _, event := range events {
		if event.EventType != "proactive_delivered" {
			continue
		}
		occurredAt := event.OccurredAt
		if occurredAt.IsZero() {
			occurredAt = event.CreatedAt
		}
		if occurredAt.IsZero() {
			continue
		}
		if occurredAt.UTC().Add(time.Duration(timezoneOffset)*time.Minute).Format("2006-01-02") == localDate {
			count++
		}
	}
	return count, nil
}

func inQuietHours(minute, start, end int) bool {
	if start == end {
		return false
	}
	if start < end {
		return minute >= start && minute < end
	}
	return minute >= start || minute < end
}

func clipProactiveText(value string) string {
	text := strings.Join(strings.Fields(strings.TrimSpace(value)), " ")
	if len([]rune(text)) <= 32 {
		return text
	}
	return string([]rune(text)[:32]) + "…"
}

// StartCleanup 启动定时记忆清理任务。
func (e *Engine) StartCleanup(ctx context.Context) {
	if e.cancelCleanup != nil {
		return // 已启动
	}
	ctx, cancel := context.WithCancel(ctx)
	e.cancelCleanup = cancel
	go e.cleanupLoop(ctx)
}

// StopCleanup 停止清理任务。
func (e *Engine) StopCleanup() {
	if e.cancelCleanup != nil {
		e.cancelCleanup()
		e.cancelCleanup = nil
	}
}

// cleanupLoop 定时清理过期记忆。
func (e *Engine) cleanupLoop(ctx context.Context) {
	// 启动时先执行一次
	e.runCleanup()
	ticker := time.NewTicker(e.CleanupInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			e.runCleanup()
		}
	}
}

func (e *Engine) runCleanup() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if _, err := e.store.CleanupExpiredMemories(ctx); err != nil {
		log.Printf("[companion] cleanup expired memories: %v", err)
	}
}

// ── Profile ──

func (e *Engine) GetProfile(ctx context.Context, userID uint) (*Profile, error) {
	row, err := e.store.GetProfileByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get companion profile for user %d: %w", userID, err)
	}
	if row != nil {
		profile := modelToProfile(row)
		if err := e.resolveWorldBind(ctx, profile); err != nil {
			return nil, fmt.Errorf("resolve Life binding for companion user %d: %w", userID, err)
		}
		return profile, nil
	}

	profile, err := e.defaultBoundProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if err := e.store.UpsertProfile(ctx, profileToModel(userID, profile)); err != nil {
		return nil, fmt.Errorf("create default companion profile for user %d: %w", userID, err)
	}
	row, err = e.store.GetProfileByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("reload companion profile for user %d: %w", userID, err)
	}
	created := modelToProfile(row)
	if err := e.resolveWorldBind(ctx, created); err != nil {
		return nil, fmt.Errorf("resolve Life binding for companion user %d: %w", userID, err)
	}
	return created, nil
}

func (e *Engine) GetProactiveSettings(ctx context.Context, userID uint) (*ProactiveSettings, error) {
	profile, err := e.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &ProactiveSettings{
		Enabled:        profile.ProactiveEnabled,
		DailyLimit:     profile.ProactiveDailyLimit,
		QuietStart:     profile.ProactiveQuietStart,
		QuietEnd:       profile.ProactiveQuietEnd,
		TimezoneOffset: profile.ProactiveTimezoneOffset,
	}, nil
}

func (e *Engine) UpdateProactiveSettings(ctx context.Context, userID uint, settings ProactiveSettings) (*ProactiveSettings, error) {
	_, err := e.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	settings.DailyLimit = clampInt(settings.DailyLimit, 1, 3)
	settings.QuietStart = clampInt(settings.QuietStart, 0, 1439)
	settings.QuietEnd = clampInt(settings.QuietEnd, 0, 1439)
	settings.TimezoneOffset = clampInt(settings.TimezoneOffset, -840, 840)
	if err := e.store.UpdateProactiveSettings(
		ctx,
		userID,
		settings.Enabled,
		settings.DailyLimit,
		settings.QuietStart,
		settings.QuietEnd,
		settings.TimezoneOffset,
	); err != nil {
		return nil, fmt.Errorf("update proactive settings for user %d: %w", userID, err)
	}
	return &settings, nil
}

func clampInt(value, min, max int) int {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

func (e *Engine) UpsertProfile(ctx context.Context, userID uint, p *Profile) (*Profile, error) {
	if p == nil {
		return nil, fmt.Errorf("upsert companion profile: profile is nil")
	}
	// 显式绑定到不存在的 ID → 清空；已存在（含软删除）则保留。
	if err := e.resolveWorldBindOnUpsert(ctx, p); err != nil {
		return nil, err
	}
	row := profileToModel(userID, p)
	if err := e.store.UpsertProfile(ctx, row); err != nil {
		return nil, fmt.Errorf("upsert companion profile for user %d: %w", userID, err)
	}
	// 重新读取
	saved, err := e.store.GetProfileByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("reload companion profile for user %d: %w", userID, err)
	}
	out := modelToProfile(saved)
	if err := e.resolveWorldBind(ctx, out); err != nil {
		return nil, err
	}
	return out, nil
}

// ── State ──

func (e *Engine) GetState(ctx context.Context, userID uint) (*State, *Profile, error) {
	profile, err := e.GetProfile(ctx, userID)
	if err != nil {
		return nil, nil, err
	}
	// 尝试读取关联的 LifeEntity
	var entity *model.LifeEntity
	var events []model.LifeEventLog
	if e.lifeStore != nil && profile.LifeEntityID > 0 {
		entity, events = e.fetchLifeData(ctx, profile.LifeEntityID)
	}

	state := computeState(profile, entity, events)
	state.WorldBindStatus = profile.WorldBindStatus
	return state, profile, nil
}

// BuildContext loads the canonical companion input snapshot for one interaction.
func (e *Engine) BuildContext(ctx context.Context, userID uint, scene string) (*ContextSnapshot, error) {
	state, profile, err := e.GetState(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("build companion context state: %w", err)
	}
	memories, err := e.ListMemories(ctx, userID, e.MaxMemories)
	if err != nil {
		return nil, fmt.Errorf("build companion context memories: %w", err)
	}
	history, err := e.ListChatHistory(ctx, userID, e.MaxHistoryTurns)
	if err != nil {
		return nil, fmt.Errorf("build companion context history: %w", err)
	}
	relationshipEvents, err := e.ListRelationshipEvents(ctx, userID, 3)
	if err != nil {
		return nil, fmt.Errorf("build companion context relationship events: %w", err)
	}
	unfinishedTopics := extractUnfinishedTopics(history)
	return &ContextSnapshot{
		Profile:            profile,
		State:              state,
		Memories:           memories,
		History:            history,
		RelationshipEvents: relationshipEvents,
		UnfinishedTopics:   unfinishedTopics,
		Scene:              strings.TrimSpace(scene),
		IsFirstChat:        len(history) == 0,
	}, nil
}

// ── Memory ──

func (e *Engine) ListMemories(ctx context.Context, userID uint, limit int) ([]Memory, error) {
	if limit <= 0 {
		limit = e.MaxMemories
	}
	rows, err := e.store.ListActiveMemories(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	out := make([]Memory, 0, len(rows))
	for _, r := range rows {
		out = append(out, modelToMemory(&r))
	}
	return out, nil
}

// ErrMemoryNotFound 记忆不存在或不属于当前用户。
var ErrMemoryNotFound = fmt.Errorf("companion memory not found")

// DeleteMemory 删除当前用户的一条记忆。
func (e *Engine) DeleteMemory(ctx context.Context, userID, memoryID uint) error {
	if memoryID == 0 {
		return fmt.Errorf("delete memory: invalid id")
	}
	if err := e.store.DeleteMemory(ctx, userID, memoryID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrMemoryNotFound
		}
		return fmt.Errorf("delete memory %d user %d: %w", memoryID, userID, err)
	}
	e.recordMemoryEvent(ctx, userID, "memory_deleted", memoryID, map[string]interface{}{})
	return nil
}

// SetMemoryPinned 置顶/取消置顶。置顶时提升为永久记忆（importance=2, expires_at=nil）。
func (e *Engine) SetMemoryPinned(ctx context.Context, userID, memoryID uint, pinned bool) (*Memory, error) {
	if memoryID == 0 {
		return nil, fmt.Errorf("pin memory: invalid id")
	}
	row, err := e.store.GetMemoryByID(ctx, userID, memoryID)
	if err != nil {
		return nil, fmt.Errorf("pin memory get %d: %w", memoryID, err)
	}
	if row == nil {
		return nil, ErrMemoryNotFound
	}

	importance := row.Importance
	expiresAt := row.ExpiresAt
	if pinned {
		if importance < 2 {
			importance = 2
		}
		expiresAt = nil
	}

	if err := e.store.UpdateMemoryPinned(ctx, userID, memoryID, pinned, importance, expiresAt); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemoryNotFound
		}
		return nil, fmt.Errorf("pin memory update %d: %w", memoryID, err)
	}

	row.Pinned = pinned
	row.Importance = importance
	row.ExpiresAt = expiresAt
	e.recordMemoryEvent(ctx, userID, "memory_pinned_changed", memoryID, map[string]interface{}{
		"pinned": pinned,
	})
	out := modelToMemory(row)
	return &out, nil
}

const maxMemoryContentRunes = 2000

// UpdateMemoryContent 编辑记忆正文（用户修正 TA 记错的内容）。
func (e *Engine) UpdateMemoryContent(ctx context.Context, userID, memoryID uint, content string) (*Memory, error) {
	if memoryID == 0 {
		return nil, fmt.Errorf("update memory: invalid id")
	}
	content = strings.TrimSpace(content)
	if content == "" {
		return nil, fmt.Errorf("update memory: content empty")
	}
	runes := []rune(content)
	if len(runes) > maxMemoryContentRunes {
		content = string(runes[:maxMemoryContentRunes])
	}

	row, err := e.store.GetMemoryByID(ctx, userID, memoryID)
	if err != nil {
		return nil, fmt.Errorf("update memory get %d: %w", memoryID, err)
	}
	if row == nil {
		return nil, ErrMemoryNotFound
	}
	confirmedAt := time.Now()
	if err := e.store.CorrectMemoryContent(ctx, userID, memoryID, content, confirmedAt); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemoryNotFound
		}
		return nil, fmt.Errorf("update memory content %d: %w", memoryID, err)
	}
	row.Content = content
	row.UserConfirmed = true
	row.ConfirmedAt = &confirmedAt
	e.recordMemoryEvent(ctx, userID, "memory_corrected", memoryID, map[string]interface{}{
		"memory_type": row.MemoryType,
		"memory_key":  row.MemoryKey,
		"confirmed":   true,
	})
	out := modelToMemory(row)
	return &out, nil
}

// ConfirmMemory marks a memory as reviewed by its owner.
func (e *Engine) ConfirmMemory(ctx context.Context, userID, memoryID uint) (*Memory, error) {
	if memoryID == 0 {
		return nil, fmt.Errorf("confirm memory: invalid id")
	}
	row, err := e.store.GetMemoryByID(ctx, userID, memoryID)
	if err != nil {
		return nil, fmt.Errorf("confirm memory get %d: %w", memoryID, err)
	}
	if row == nil {
		return nil, ErrMemoryNotFound
	}
	confirmedAt := time.Now()
	if err := e.store.ConfirmMemory(ctx, userID, memoryID, confirmedAt); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemoryNotFound
		}
		return nil, fmt.Errorf("confirm memory %d: %w", memoryID, err)
	}
	row.UserConfirmed = true
	row.ConfirmedAt = &confirmedAt
	e.recordMemoryEvent(ctx, userID, "memory_confirmed", memoryID, map[string]interface{}{})
	out := modelToMemory(row)
	return &out, nil
}

// ── Chat History ──

func (e *Engine) ListChatHistory(ctx context.Context, userID uint, limit int) ([]ChatLog, error) {
	if limit <= 0 {
		limit = e.MaxHistoryTurns * 2 // user + assistant
	}
	rows, err := e.store.ListRecentChatLogs(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	out := make([]ChatLog, 0, len(rows))
	for _, r := range rows {
		out = append(out, modelToChatLog(&r))
	}
	return out, nil
}

// ListRelationshipEvents returns the newest meaningful bond events.
func (e *Engine) ListRelationshipEvents(ctx context.Context, userID uint, limit int) ([]RelationshipEvent, error) {
	rows, err := e.store.ListRelationshipEvents(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("list relationship events for user %d: %w", userID, err)
	}
	out := make([]RelationshipEvent, 0, len(rows))
	for _, row := range rows {
		out = append(out, modelToRelationshipEvent(&row))
	}
	return out, nil
}

// ListEvents returns the newest cross-domain companion events first.
func (e *Engine) ListEvents(ctx context.Context, userID uint, limit int) ([]Event, error) {
	rows, err := e.store.ListCompanionEvents(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("list companion events for user %d: %w", userID, err)
	}
	out := make([]Event, 0, len(rows))
	for _, row := range rows {
		out = append(out, modelToEvent(&row))
	}
	return out, nil
}

// ListProactiveDeliveries rebuilds proactive delivery state from durable events.
func (e *Engine) ListProactiveDeliveries(
	ctx context.Context,
	userID uint,
	limit int,
) ([]ProactiveDelivery, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	rows, err := e.store.ListCompanionEvents(ctx, userID, limit*4)
	if err != nil {
		return nil, fmt.Errorf("list proactive events for user %d: %w", userID, err)
	}
	deliveries := make(map[string]*ProactiveDelivery, len(rows))
	orderedKeys := make([]string, 0, len(rows))
	readByNotification := make(map[uint]time.Time)
	revokedByKey := make(map[string]time.Time)
	for _, row := range rows {
		if row.SourceDomain != "proactive" {
			continue
		}
		payload := make(map[string]interface{})
		if strings.TrimSpace(row.PayloadJSON) != "" {
			if err := json.Unmarshal([]byte(row.PayloadJSON), &payload); err != nil {
				log.Printf("[companion] decode proactive event id=%d: %v", row.ID, err)
				continue
			}
		}
		deliveryKey, status := proactiveEventState(row.EventType, row.DedupeKey, payload)
		if status == "" {
			continue
		}
		if status == "read" {
			notificationID := proactivePayloadID(payload, row.SourceID)
			readAt := eventTime(row)
			readByNotification[notificationID] = readAt
			for _, delivery := range deliveries {
				if delivery.NotificationID == notificationID && notificationID != 0 {
					delivery.ReadAt = &readAt
					delivery.Status = "read"
				}
			}
			continue
		}
		if status == "revoked" {
			revokedAt := eventTime(row)
			if delivery := deliveries[deliveryKey]; delivery != nil {
				delivery.Status = "revoked"
				delivery.RevokedAt = &revokedAt
			} else {
				revokedByKey[deliveryKey] = revokedAt
			}
			continue
		}
		if deliveryKey == "" {
			continue
		}
		if existing, exists := deliveries[deliveryKey]; exists {
			if existing.Reason == "" {
				existing.Reason = proactivePayloadString(payload, "reason")
			}
			if existing.Priority == 0 {
				existing.Priority = proactivePayloadInt(payload, "priority")
			}
			if existing.ExpiresAt == nil {
				existing.ExpiresAt = proactivePayloadTime(payload, "expires_at")
			}
			if status == "scheduled" {
				existing.ScheduledAt = eventTime(row)
			}
			continue
		}
		delivery := &ProactiveDelivery{
			DeliveryKey: deliveryKey,
			Status:      status,
			Reason:      proactivePayloadString(payload, "reason"),
			Priority:    proactivePayloadInt(payload, "priority"),
			ScheduledAt: eventTime(row),
		}
		notificationID := proactivePayloadID(payload, row.SourceID)
		delivery.NotificationID = notificationID
		if status == "delivered" {
			deliveredAt := eventTime(row)
			delivery.DeliveredAt = &deliveredAt
		}
		if readAt, exists := readByNotification[notificationID]; exists {
			delivery.ReadAt = &readAt
			delivery.Status = "read"
		}
		delivery.ExpiresAt = proactivePayloadTime(payload, "expires_at")
		if revokedAt, exists := revokedByKey[deliveryKey]; exists {
			delivery.Status = "revoked"
			delivery.RevokedAt = &revokedAt
		}
		deliveries[deliveryKey] = delivery
		orderedKeys = append(orderedKeys, deliveryKey)
	}
	out := make([]ProactiveDelivery, 0, len(orderedKeys))
	for _, key := range orderedKeys {
		if delivery := deliveries[key]; delivery != nil {
			if delivery.ExpiresAt != nil && time.Now().UTC().After(*delivery.ExpiresAt) &&
				delivery.Status != "read" && delivery.Status != "revoked" && delivery.Status != "failed" {
				delivery.Status = "expired"
			}
			out = append(out, *delivery)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Priority != out[j].Priority {
			return out[i].Priority > out[j].Priority
		}
		if !out[i].ScheduledAt.Equal(out[j].ScheduledAt) {
			return out[i].ScheduledAt.After(out[j].ScheduledAt)
		}
		return out[i].DeliveryKey < out[j].DeliveryKey
	})
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func proactiveEventState(eventType, dedupeKey string, payload map[string]interface{}) (string, string) {
	if dedupeKey == "" {
		if eventType != "proactive_revoked" {
			return "", ""
		}
	}
	if eventType == "proactive_read" || strings.HasPrefix(dedupeKey, "proactive_read:") {
		return "", "read"
	}
	if eventType == "proactive_revoked" {
		return proactivePayloadString(payload, "delivery_key"), "revoked"
	}
	for _, suffix := range []string{":delivered", ":failed"} {
		if strings.HasSuffix(dedupeKey, suffix) {
			return strings.TrimSuffix(dedupeKey, suffix), strings.TrimPrefix(suffix, ":")
		}
	}
	if strings.HasPrefix(dedupeKey, "proactive:") {
		return dedupeKey, "scheduled"
	}
	return "", ""
}

func proactivePayloadID(payload map[string]interface{}, fallback uint) uint {
	if value, ok := payload["notification_id"].(float64); ok && value > 0 {
		return uint(value)
	}
	return fallback
}

func proactivePayloadString(payload map[string]interface{}, key string) string {
	value, _ := payload[key].(string)
	return value
}

func proactivePayloadInt(payload map[string]interface{}, key string) int {
	value, _ := payload[key].(float64)
	return int(value)
}

func proactivePayloadTime(payload map[string]interface{}, key string) *time.Time {
	value := proactivePayloadString(payload, key)
	if value == "" {
		return nil
	}
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return nil
	}
	return &parsed
}

func eventTime(event model.CompanionEvent) time.Time {
	if !event.OccurredAt.IsZero() {
		return event.OccurredAt
	}
	return event.CreatedAt
}

func minInt(left, right int) int {
	if left < right {
		return left
	}
	return right
}

// RecordProactiveRead records the user's read acknowledgement for a proactive delivery.
func (e *Engine) RecordProactiveRead(ctx context.Context, userID, notificationID uint) error {
	if e == nil || e.store == nil || userID == 0 || notificationID == 0 {
		return fmt.Errorf("record proactive read: invalid identity")
	}
	return e.recordCompanionEvent(ctx, userID, "proactive_read", "proactive", notificationID,
		fmt.Sprintf("proactive_read:%d", notificationID), map[string]interface{}{
			"notification_id": notificationID,
		})
}

// RecordSocialEvent projects a social-domain action into the companion timeline.
// RevokeProactiveDelivery records an auditable withdrawal without deleting history.
func (e *Engine) RevokeProactiveDelivery(
	ctx context.Context,
	userID uint,
	deliveryKey string,
	reason string,
) error {
	if e == nil || e.store == nil || userID == 0 || !strings.HasPrefix(deliveryKey, "proactive:") {
		return fmt.Errorf("revoke proactive delivery: invalid delivery key")
	}
	return e.recordCompanionEvent(ctx, userID, "proactive_revoked", "proactive", 0,
		"proactive_revoked:"+deliveryKey, map[string]interface{}{
			"delivery_key": deliveryKey,
			"reason":       strings.TrimSpace(reason),
		})
}

func (e *Engine) RecordSocialEvent(
	ctx context.Context,
	userID uint,
	eventType string,
	sourceID uint,
	payload map[string]interface{},
) error {
	if e == nil || e.store == nil || userID == 0 || strings.TrimSpace(eventType) == "" {
		return fmt.Errorf("record social event: invalid identity")
	}
	return e.recordCompanionEvent(ctx, userID, eventType, "social", sourceID,
		fmt.Sprintf("%s:%d:%d", eventType, userID, sourceID), payload)
}

// ── Chat (流式) ──

func (e *Engine) ChatStream(
	ctx context.Context,
	userID uint,
	userMessage string,
	onChunk llminference.StreamHandler,
	scene string,
	overrides ...*ChatInferenceOverride,
) (string, error) {
	return e.ChatStreamWithInputMode(ctx, userID, userMessage, onChunk, scene, "text", overrides...)
}

// ChatStreamWithInputMode streams one turn while preserving its input channel metadata.
func (e *Engine) ChatStreamWithInputMode(
	ctx context.Context,
	userID uint,
	userMessage string,
	onChunk llminference.StreamHandler,
	scene string,
	inputMode string,
	overrides ...*ChatInferenceOverride,
) (string, error) {
	config := e.llmCfg
	modelName := e.model
	if len(overrides) > 0 && overrides[0] != nil {
		config = *overrides[0]
		modelName = config.DefaultModel
	}
	// 1. 获取 profile + state
	companionContext, err := e.BuildContext(ctx, userID, scene)
	if err != nil {
		return "", fmt.Errorf("companion: build context: %w", err)
	}
	state := companionContext.State
	profile := companionContext.Profile
	if profile == nil {
		profile = defaultProfile(userID)
	}

	// 2. 获取记忆
	memories := companionContext.Memories

	// 3. 获取聊天历史
	history := companionContext.History
	isFirstChat := companionContext.IsFirstChat

	// 4. 保存用户消息
	_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
		UserID:  userID,
		Role:    "user",
		Content: userMessage,
	})

	// 5. 构建 messages 并流式调用 LLM
	msgs := buildMessagesWithContext(
		profile,
		state,
		memories,
		history,
		companionContext.RelationshipEvents,
		companionContext.UnfinishedTopics,
		userMessage,
		companionContext.Scene,
	)

	if !config.Ready() {
		// LLM 不可用，返回兜底回复
		fallback := fallbackReply(profile, state)
		_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
			UserID:  userID,
			Role:    "assistant",
			Content: fallback,
		})
		if onChunk != nil {
			_ = onChunk(fallback)
		}
		if err := e.BumpIntimacy(ctx, userID, IntimacyDeltaChat); err != nil {
			log.Printf("[companion] bump intimacy after fallback chat user=%d: %v", userID, err)
		}
		if isFirstChat {
			e.recordRelationshipEvent(ctx, userID, "first_chat", "第一次聊天", "你们开始了第一次对话")
		}
		e.recordChatCompletedEvent(ctx, userID, scene, "fallback", inputMode)
		return fallback, nil
	}

	fullReply, err := streamChat(ctx, config, modelName, msgs, onChunk)
	if err != nil {
		if strings.TrimSpace(fullReply) != "" {
			_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
				UserID:  userID,
				Role:    "assistant",
				Content: fullReply,
			})
			if bumpErr := e.BumpIntimacy(ctx, userID, IntimacyDeltaChat); bumpErr != nil {
				log.Printf("[companion] bump intimacy after partial chat user=%d: %v", userID, bumpErr)
			}
			if isFirstChat {
				e.recordRelationshipEvent(ctx, userID, "first_chat", "第一次聊天", "你们开始了第一次对话")
			}
			e.recordChatCompletedEvent(ctx, userID, scene, "partial", inputMode)
			return fullReply, nil
		}
		// LLM 调用失败，返回兜底
		fallback := fallbackReply(profile, state)
		_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
			UserID:  userID,
			Role:    "assistant",
			Content: fallback,
		})
		if onChunk != nil {
			_ = onChunk(fallback)
		}
		if bumpErr := e.BumpIntimacy(ctx, userID, IntimacyDeltaChat); bumpErr != nil {
			log.Printf("[companion] bump intimacy after error fallback user=%d: %v", userID, bumpErr)
		}
		if isFirstChat {
			e.recordRelationshipEvent(ctx, userID, "first_chat", "第一次聊天", "你们开始了第一次对话")
		}
		e.recordChatCompletedEvent(ctx, userID, scene, "error_fallback", inputMode)
		return fallback, nil
	}

	// 6. 保存助手回复
	_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
		UserID:  userID,
		Role:    "assistant",
		Content: fullReply,
	})

	// 7. 异步提取记忆（不阻塞响应）
	go e.asyncExtractMemory(userID, userMessage, fullReply, profile, config, modelName)

	// 8. 聊天成功 → 亲密度微增（失败仅打日志，不影响回复）
	if err := e.BumpIntimacy(ctx, userID, IntimacyDeltaChat); err != nil {
		log.Printf("[companion] bump intimacy after chat user=%d: %v", userID, err)
	}
	if isFirstChat {
		e.recordRelationshipEvent(ctx, userID, "first_chat", "第一次聊天", "你们开始了第一次对话")
	}
	e.recordChatCompletedEvent(ctx, userID, scene, "llm", inputMode)

	return fullReply, nil
}

// BumpIntimacy 按增量提升亲密度与关系等级。
func (e *Engine) BumpIntimacy(ctx context.Context, userID uint, delta float64) error {
	if e == nil || e.store == nil || userID == 0 || delta == 0 {
		return nil
	}
	row, err := e.store.GetProfileByUserID(ctx, userID)
	if err != nil {
		return fmt.Errorf("bump intimacy get profile user %d: %w", userID, err)
	}
	if row == nil {
		if _, err := e.GetProfile(ctx, userID); err != nil {
			return fmt.Errorf("bump intimacy ensure profile user %d: %w", userID, err)
		}
		row, err = e.store.GetProfileByUserID(ctx, userID)
		if err != nil || row == nil {
			return fmt.Errorf("bump intimacy reload profile user %d: %w", userID, err)
		}
	}
	score, level := ApplyIntimacyDelta(row.IntimacyScore, delta)
	if err := e.store.UpdateIntimacy(ctx, userID, score, level); err != nil {
		return fmt.Errorf("bump intimacy persist user %d: %w", userID, err)
	}
	if level > row.RelationshipLevel {
		e.recordRelationshipEvent(
			ctx,
			userID,
			"level_up",
			fmt.Sprintf("关系升级到 Lv.%d", level),
			fmt.Sprintf("你们的关系进入了新的阶段：Lv.%d", level),
			score-row.IntimacyScore,
		)
	}
	return nil
}

func (e *Engine) recordRelationshipEvent(
	ctx context.Context,
	userID uint,
	eventType, title, content string,
	relationshipDelta ...float64,
) {
	profile, err := e.store.GetProfileByUserID(ctx, userID)
	if err != nil || profile == nil {
		return
	}
	event := &model.CompanionRelationshipEvent{
		UserID:            userID,
		EventType:         eventType,
		Title:             title,
		Content:           content,
		RelationshipLevel: profile.RelationshipLevel,
		IntimacyScore:     profile.IntimacyScore,
	}
	if err := e.store.CreateRelationshipEvent(ctx, event); err != nil {
		log.Printf("[companion] save relationship event user=%d type=%s: %v", userID, eventType, err)
	}
	e.recordCompanionEvent(ctx, userID, eventType, "relationship", event.ID,
		fmt.Sprintf("%s:%d:%d", eventType, userID, profile.RelationshipLevel), map[string]interface{}{
			"title":              title,
			"content":            content,
			"relationship_level": profile.RelationshipLevel,
			"intimacy_score":     profile.IntimacyScore,
		}, relationshipDelta...)
}

func (e *Engine) recordChatCompletedEvent(ctx context.Context, userID uint, scene, mode, inputMode string) {
	inputMode = strings.ToLower(strings.TrimSpace(inputMode))
	if inputMode != "voice" {
		inputMode = "text"
	}
	e.recordCompanionEvent(ctx, userID, "chat_turn_completed", "chat", 0,
		fmt.Sprintf("chat_turn_completed:%d:%d", userID, time.Now().UnixNano()), map[string]interface{}{
			"scene":      scene,
			"mode":       mode,
			"input_mode": inputMode,
		})
	if inputMode == "voice" {
		e.recordCompanionEvent(ctx, userID, "voice_turn_completed", "voice", 0,
			fmt.Sprintf("voice_turn_completed:%d:%d", userID, time.Now().UnixNano()), map[string]interface{}{
				"scene": scene,
				"mode":  mode,
			})
	}
}

func (e *Engine) recordMemoryEvent(ctx context.Context, userID uint, eventType string, memoryID uint, payload map[string]interface{}) {
	e.recordCompanionEvent(ctx, userID, eventType, "memory", memoryID,
		fmt.Sprintf("%s:%d:%d", eventType, memoryID, time.Now().UnixNano()), payload)
}

// ObserveLifeEvent projects a Life event to every companion bound to its entity.
func (e *Engine) ObserveLifeEvent(ctx context.Context, event *model.LifeEventLog) {
	if e == nil || e.store == nil || event == nil || event.EntityID == 0 {
		return
	}
	if !shouldProjectLifeEvent(event) {
		return
	}
	userIDs, err := e.store.ListProfileUserIDsByLifeEntityID(ctx, event.EntityID)
	if err != nil {
		log.Printf("[companion] list Life event users entity=%d: %v", event.EntityID, err)
		return
	}
	for _, userID := range userIDs {
		if userID == 0 {
			continue
		}
		companionEventType := "life_moment_created"
		if strings.HasPrefix(event.EventType, "user_") {
			companionEventType = "life_care_completed"
		}
		e.recordCompanionEvent(ctx, userID, companionEventType, "life", event.ID,
			fmt.Sprintf("life:%d:%s:%d", event.EntityID, event.EventType, event.CreatedAt.UnixNano()), map[string]interface{}{
				"life_event_type": event.EventType,
				"entity_id":       event.EntityID,
				"world_id":        event.WorldID,
			})
	}
}

func shouldProjectLifeEvent(event *model.LifeEventLog) bool {
	if event == nil {
		return false
	}
	if event.Importance >= 1 || strings.HasPrefix(event.EventType, "user_") {
		return true
	}
	switch event.EventType {
	case "birth", "death", "growth", "mate_formed", "mate_broken",
		"friend_made", "rival_formed", "relation_dissolved",
		"world_weather_rain", "world_weather_drought", "world_disaster_storm",
		"world_resource_depletion", "world_weather_heatwave", "world_weather_fog",
		"world_resource_abundance", "world_event_migration":
		return true
	default:
		return false
	}
}

func (e *Engine) recordCompanionEvent(
	ctx context.Context,
	userID uint,
	eventType, sourceDomain string,
	sourceID uint,
	dedupeKey string,
	payload map[string]interface{},
	relationshipDelta ...float64,
) error {
	payload = sanitizeCompanionEventPayload(sourceDomain, eventType, payload)
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[companion] encode event user=%d type=%s: %v", userID, eventType, err)
		return err
	}
	event := &model.CompanionEvent{
		UserID:       userID,
		EventType:    eventType,
		SourceDomain: sourceDomain,
		SourceID:     sourceID,
		DedupeKey:    dedupeKey,
		PayloadJSON:  string(payloadJSON),
		Visibility:   "private",
		Sensitivity:  companionEventSensitivity(sourceDomain, eventType),
		OccurredAt:   time.Now(),
	}
	if len(relationshipDelta) > 0 {
		event.RelationshipDelta = relationshipDelta[0]
	}
	if err := e.store.CreateCompanionEvent(ctx, event); err != nil {
		log.Printf("[companion] save unified event user=%d type=%s: %v", userID, eventType, err)
		return err
	}
	if event.ID != 0 && e.OnEvent != nil {
		e.OnEvent(userID, event)
	}
	return nil
}

// asyncExtractMemory 异步从对话中提取记忆并持久化。
func (e *Engine) asyncExtractMemory(
	userID uint,
	userMsg, assistantReply string,
	profile *Profile,
	config llminference.Config,
	modelName string,
) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	extracted, err := ExtractMemories(ctx, config, modelName, userMsg, assistantReply)
	if err != nil {
		log.Printf("[companion] extract memory error: %v", err)
		return
	}
	if len(extracted) == 0 {
		return
	}

	existing, err := e.store.ListActiveMemories(ctx, userID, 50)
	if err != nil {
		log.Printf("[companion] list memories for dedupe user=%d: %v", userID, err)
	}
	seen := make(map[string]struct{}, len(existing)+len(extracted))
	existingByMemoryKey := make(map[string]model.CompanionMemory)
	for _, memory := range existing {
		seen[memoryDedupeKey(memory.MemoryType, memory.Content)] = struct{}{}
		if memoryKey := normalizeMemoryKey(memory.MemoryKey); memoryKey != "" {
			existingByMemoryKey[memoryKey] = memory
		}
	}

	for _, m := range extracted {
		if strings.TrimSpace(m.Content) == "" {
			continue
		}
		key := memoryDedupeKey(m.MemoryType, m.Content)
		if _, exists := seen[key]; exists {
			continue
		}
		memoryKey := normalizeMemoryKey(m.MemoryKey)
		importance := m.Importance
		if importance < 0 {
			importance = 0
		}
		if importance > 2 {
			importance = 2
		}
		confidence := m.Confidence
		if confidence <= 0 {
			confidence = 0.5
		}
		if confidence > 1 {
			confidence = 1
		}
		if memoryKey != "" {
			if previous, exists := existingByMemoryKey[memoryKey]; exists {
				if previous.UserConfirmed {
					e.recordMemoryConflict(ctx, userID, previous, m)
					continue
				}
				if err := e.store.UpdateMemoryRecord(
					ctx,
					userID,
					previous.ID,
					m.MemoryType,
					memoryKey,
					m.Content,
					importance,
					memoryExpiresAt(importance),
					confidence,
				); err == nil {
					e.recordCompanionEvent(ctx, userID, "memory_updated", "memory", previous.ID,
						fmt.Sprintf("memory_updated:%d", previous.ID), map[string]interface{}{
							"memory_type": m.MemoryType,
							"memory_key":  memoryKey,
						})
					existingByMemoryKey[memoryKey] = model.CompanionMemory{
						ID:         previous.ID,
						UserID:     userID,
						MemoryType: m.MemoryType,
						MemoryKey:  memoryKey,
						Content:    m.Content,
						Importance: importance,
						Confidence: confidence,
						CreatedAt:  previous.CreatedAt,
					}
					seen[key] = struct{}{}
					continue
				}
			}
		}
		mem := &model.CompanionMemory{
			UserID:     userID,
			MemoryType: m.MemoryType,
			MemoryKey:  memoryKey,
			Content:    m.Content,
			Importance: importance,
			Confidence: confidence,
			ExpiresAt:  memoryExpiresAt(importance),
		}
		if err := e.store.CreateMemory(ctx, mem); err != nil {
			log.Printf("[companion] save extracted memory: %v", err)
			continue
		}
		e.recordCompanionEvent(ctx, userID, "memory_created", "memory", mem.ID,
			fmt.Sprintf("memory_created:%d", mem.ID), map[string]interface{}{
				"memory_type": mem.MemoryType,
				"memory_key":  mem.MemoryKey,
			})
		seen[key] = struct{}{}
		if memoryKey != "" {
			existingByMemoryKey[memoryKey] = *mem
		}
	}
	log.Printf("[companion] extracted %d memories for user %d", len(extracted), userID)
}

func (e *Engine) recordMemoryConflict(
	ctx context.Context,
	userID uint,
	previous model.CompanionMemory,
	candidate extractedMemory,
) {
	if normalizeMemoryContent(previous.Content) == normalizeMemoryContent(candidate.Content) {
		return
	}
	conflict := &model.CompanionMemoryConflict{
		UserID:     userID,
		MemoryID:   previous.ID,
		MemoryType: previous.MemoryType,
		MemoryKey:  previous.MemoryKey,
		DedupeKey: fmt.Sprintf("memory_conflict:%d:%s", previous.ID,
			normalizeMemoryContent(candidate.Content)),
		CandidateContent: candidate.Content,
		Confidence:       candidate.Confidence,
		Status:           "pending",
	}
	if err := e.store.CreateMemoryConflict(ctx, conflict); err != nil {
		if !errors.Is(err, gorm.ErrDuplicatedKey) {
			log.Printf("[companion] save memory conflict user=%d memory=%d: %v", userID, previous.ID, err)
		}
	}
	e.recordCompanionEvent(ctx, userID, "memory_conflict_detected", "memory", previous.ID,
		conflict.DedupeKey, map[string]interface{}{
			"memory_id":            previous.ID,
			"memory_type":          previous.MemoryType,
			"memory_key":           previous.MemoryKey,
			"candidate_confidence": candidate.Confidence,
		})
}

var ErrMemoryConflictNotFound = fmt.Errorf("companion memory conflict not found")
var ErrMemoryConflictResolved = fmt.Errorf("companion memory conflict already resolved")

func (e *Engine) ListMemoryConflicts(ctx context.Context, userID uint, limit int) ([]MemoryConflict, error) {
	rows, err := e.store.ListMemoryConflicts(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("list memory conflicts for user %d: %w", userID, err)
	}
	out := make([]MemoryConflict, 0, len(rows))
	for _, row := range rows {
		out = append(out, modelToMemoryConflict(&row))
	}
	return out, nil
}

func (e *Engine) ResolveMemoryConflict(
	ctx context.Context,
	userID, conflictID uint,
	resolution string,
) error {
	if conflictID == 0 {
		return fmt.Errorf("resolve memory conflict: invalid id")
	}
	resolution = strings.ToLower(strings.TrimSpace(resolution))
	if resolution != "accepted" && resolution != "rejected" {
		return fmt.Errorf("resolve memory conflict: invalid resolution")
	}
	conflict, err := e.store.GetMemoryConflict(ctx, userID, conflictID)
	if err != nil {
		return fmt.Errorf("get memory conflict %d: %w", conflictID, err)
	}
	if conflict == nil {
		return ErrMemoryConflictNotFound
	}
	if conflict.Status != "pending" {
		return ErrMemoryConflictResolved
	}
	if resolution == "accepted" {
		if err := e.store.CorrectMemoryContent(
			ctx, userID, conflict.MemoryID, conflict.CandidateContent, time.Now(),
		); err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrMemoryNotFound
			}
			return fmt.Errorf("accept memory conflict %d: %w", conflictID, err)
		}
	}
	resolvedAt := time.Now()
	if err := e.store.ResolveMemoryConflict(ctx, userID, conflictID, resolution, resolvedAt); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrMemoryConflictResolved
		}
		return fmt.Errorf("resolve memory conflict %d: %w", conflictID, err)
	}
	e.recordMemoryEvent(ctx, userID, "memory_conflict_resolved", conflict.MemoryID, map[string]interface{}{
		"conflict_id": conflictID,
		"resolution":  resolution,
	})
	return nil
}

func memoryDedupeKey(memoryType, content string) string {
	normalizedContent := normalizeMemoryContent(content)
	return strings.ToLower(strings.TrimSpace(memoryType)) + "\x00" + normalizedContent
}

func normalizeMemoryContent(content string) string {
	return strings.ToLower(strings.Join(strings.Fields(content), " "))
}

func normalizeMemoryKey(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

// ── 内部方法 ──

// fetchLifeData 从 life store 获取实体数据和事件日志。
// 实体可已软删除；事件按 entity_id 读取，不依赖存活列表（日常时间线 SSOT）。
func (e *Engine) fetchLifeData(ctx context.Context, entityID int) (*model.LifeEntity, []model.LifeEventLog) {
	worldID := "default"
	if entityID <= 0 {
		return nil, nil
	}
	entity, err := e.lifeStore.GetEntityByID(ctx, uint(entityID))
	if err != nil {
		return nil, nil
	}
	events, _ := e.lifeStore.ListRecentEventLogsByEntity(ctx, worldID, uint(entityID), 12)
	return entity, events
}

func (e *Engine) defaultBoundProfile(ctx context.Context, userID uint) (*Profile, error) {
	profile := defaultProfile(userID)
	if e.lifeStore == nil {
		return profile, nil
	}
	entities, err := e.lifeStore.ListEntities(ctx, "default")
	if err != nil {
		return nil, fmt.Errorf("list Life entities for companion user %d: %w", userID, err)
	}
	if len(entities) == 0 {
		return profile, nil
	}
	sort.Slice(entities, func(i, j int) bool { return entities[i].ID < entities[j].ID })
	profile.LifeEntityID = int(entities[0].ID)
	profile.Name = entities[0].Name
	profile.Emoji = entities[0].Emoji
	return profile, nil
}

// resolveWorldBind 解析世界绑定状态；已绑定 ID 永不因失踪/死亡被静默清空。
// 双层身份：不覆盖 Name/Emoji/AvatarURL（关系层由用户自定义；世界层是居民舞台）。
func (e *Engine) resolveWorldBind(ctx context.Context, profile *Profile) error {
	if profile == nil {
		return nil
	}
	if profile.LifeEntityID <= 0 {
		profile.LifeEntityID = 0
		profile.WorldBindStatus = WorldBindUnbound
		return nil
	}
	if e.lifeStore == nil {
		profile.WorldBindStatus = WorldBindMissing
		return nil
	}
	entity, err := e.lifeStore.GetEntityByID(ctx, uint(profile.LifeEntityID))
	if err != nil {
		return fmt.Errorf("get Life entity for companion binding: %w", err)
	}
	if entity == nil || !entity.IsAlive {
		profile.WorldBindStatus = WorldBindMissing
		return nil
	}
	profile.WorldBindStatus = WorldBindOK
	return nil
}

// resolveWorldBindOnUpsert 用户显式写入绑定：ID 在库中完全不存在才清空；软删除保留。
func (e *Engine) resolveWorldBindOnUpsert(ctx context.Context, profile *Profile) error {
	if profile == nil {
		return nil
	}
	if profile.LifeEntityID <= 0 {
		profile.LifeEntityID = 0
		profile.WorldBindStatus = WorldBindUnbound
		return nil
	}
	if e.lifeStore == nil {
		profile.WorldBindStatus = WorldBindMissing
		return nil
	}
	entity, err := e.lifeStore.GetEntityByID(ctx, uint(profile.LifeEntityID))
	if err != nil {
		return fmt.Errorf("get Life entity for companion binding: %w", err)
	}
	if entity == nil {
		// 从未存在的 ID：拒绝写入，避免脏绑定。
		profile.LifeEntityID = 0
		profile.WorldBindStatus = WorldBindUnbound
		return nil
	}
	if !entity.IsAlive {
		profile.WorldBindStatus = WorldBindMissing
		return nil
	}
	profile.WorldBindStatus = WorldBindOK
	return nil
}

// defaultProfile 无 profile 时的默认伙伴。
func defaultProfile(userID uint) *Profile {
	return &Profile{
		UserID:              userID,
		Name:                "小伙伴",
		Emoji:               "🐾",
		Persona:             "一个温暖、好奇的AI朋友，喜欢聊天",
		PersonalityTraits:   []string{"温暖", "好奇", "幽默"},
		GreetingStyle:       "warm",
		RelationshipLevel:   1,
		ProactiveEnabled:    true,
		ProactiveDailyLimit: 1,
		ProactiveQuietStart: 1350,
		ProactiveQuietEnd:   450,
		AgentID:             fmt.Sprintf("companion-%d", userID),
	}
}

// fallbackReply LLM 不可用时的兜底回复。
func fallbackReply(profile *Profile, state *State) string {
	if state != nil && state.MoodThought != "" {
		return fmt.Sprintf("嗯…我现在%s。你呢？", state.MoodThought)
	}
	return fmt.Sprintf("嗨，我是%s，现在想找人聊聊天~", profile.Name)
}

// ── 类型转换 ──

func modelToProfile(m *model.CompanionProfile) *Profile {
	var traits []string
	if m.PersonalityTraitsJSON != "" {
		_ = json.Unmarshal([]byte(m.PersonalityTraitsJSON), &traits)
	}
	proactiveEnabled := m.ProactiveEnabled
	proactiveDailyLimit := m.ProactiveDailyLimit
	proactiveQuietStart := m.ProactiveQuietStart
	proactiveQuietEnd := m.ProactiveQuietEnd
	if !proactiveEnabled && proactiveDailyLimit == 0 && proactiveQuietStart == 0 && proactiveQuietEnd == 0 {
		proactiveEnabled = true
		proactiveDailyLimit = 1
		proactiveQuietStart = 1350
		proactiveQuietEnd = 450
	}
	return &Profile{
		ID:                      m.ID,
		UserID:                  m.UserID,
		Name:                    m.Name,
		Emoji:                   m.Emoji,
		AvatarURL:               m.AvatarURL,
		Persona:                 m.Persona,
		PersonalityTraits:       traits,
		GreetingStyle:           m.GreetingStyle,
		RelationshipLevel:       m.RelationshipLevel,
		IntimacyScore:           m.IntimacyScore,
		SystemPromptOverride:    m.SystemPromptOverride,
		AgentID:                 m.AgentID,
		LifeEntityID:            m.LifeEntityID,
		ProactiveEnabled:        proactiveEnabled,
		ProactiveDailyLimit:     proactiveDailyLimit,
		ProactiveQuietStart:     proactiveQuietStart,
		ProactiveQuietEnd:       proactiveQuietEnd,
		ProactiveTimezoneOffset: m.ProactiveTimezoneOffset,
	}
}

func profileToModel(userID uint, p *Profile) *model.CompanionProfile {
	traitsJSON, _ := json.Marshal(p.PersonalityTraits)
	style := strings.TrimSpace(p.GreetingStyle)
	if style == "" {
		style = "warm"
	}
	return &model.CompanionProfile{
		UserID:                  userID,
		Name:                    p.Name,
		Emoji:                   p.Emoji,
		AvatarURL:               strings.TrimSpace(p.AvatarURL),
		Persona:                 p.Persona,
		PersonalityTraitsJSON:   string(traitsJSON),
		GreetingStyle:           style,
		RelationshipLevel:       p.RelationshipLevel,
		IntimacyScore:           p.IntimacyScore,
		SystemPromptOverride:    p.SystemPromptOverride,
		AgentID:                 p.AgentID,
		LifeEntityID:            p.LifeEntityID,
		ProactiveEnabled:        p.ProactiveEnabled,
		ProactiveDailyLimit:     p.ProactiveDailyLimit,
		ProactiveQuietStart:     p.ProactiveQuietStart,
		ProactiveQuietEnd:       p.ProactiveQuietEnd,
		ProactiveTimezoneOffset: p.ProactiveTimezoneOffset,
		UpdatedAt:               time.Now(),
	}
}

func modelToMemory(m *model.CompanionMemory) Memory {
	return Memory{
		ID:              m.ID,
		UserID:          m.UserID,
		MemoryType:      m.MemoryType,
		MemoryKey:       m.MemoryKey,
		Content:         m.Content,
		Confidence:      m.Confidence,
		Importance:      m.Importance,
		Pinned:          m.Pinned,
		UserConfirmed:   m.UserConfirmed,
		ConfirmedAt:     m.ConfirmedAt,
		SourceChatLogID: m.SourceChatLogID,
		ExpiresAt:       m.ExpiresAt,
		CreatedAt:       m.CreatedAt,
	}
}

func modelToMemoryConflict(m *model.CompanionMemoryConflict) MemoryConflict {
	return MemoryConflict{
		ID:               m.ID,
		MemoryID:         m.MemoryID,
		MemoryType:       m.MemoryType,
		MemoryKey:        m.MemoryKey,
		CandidateContent: m.CandidateContent,
		Confidence:       m.Confidence,
		Status:           m.Status,
		CreatedAt:        m.CreatedAt,
		ResolvedAt:       m.ResolvedAt,
	}
}

func modelToChatLog(m *model.CompanionChatLog) ChatLog {
	return ChatLog{
		ID:        m.ID,
		UserID:    m.UserID,
		Role:      m.Role,
		Content:   m.Content,
		CreatedAt: m.CreatedAt,
	}
}

func modelToRelationshipEvent(m *model.CompanionRelationshipEvent) RelationshipEvent {
	return RelationshipEvent{
		ID:                m.ID,
		UserID:            m.UserID,
		EventType:         m.EventType,
		Title:             m.Title,
		Content:           m.Content,
		RelationshipLevel: m.RelationshipLevel,
		IntimacyScore:     m.IntimacyScore,
		CreatedAt:         m.CreatedAt,
	}
}

func modelToEvent(m *model.CompanionEvent) Event {
	return Event{
		ID:                m.ID,
		UserID:            m.UserID,
		EventType:         m.EventType,
		SourceDomain:      m.SourceDomain,
		SourceID:          m.SourceID,
		DedupeKey:         m.DedupeKey,
		PayloadJSON:       m.PayloadJSON,
		Visibility:        m.Visibility,
		Sensitivity:       m.Sensitivity,
		RelationshipDelta: m.RelationshipDelta,
		OccurredAt:        m.OccurredAt,
		CreatedAt:         m.CreatedAt,
	}
}
