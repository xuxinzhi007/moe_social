package companionbiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"sort"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/llminference"
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
	OnGreeting func(userID uint, greeting string)

	// 内部
	cancelCleanup  context.CancelFunc
	cancelGreeting context.CancelFunc
}

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
	}
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
		if e.lifeStore != nil {
			previousEntityID := profile.LifeEntityID
			if err := e.bindLifeEntity(ctx, profile); err != nil {
				if errors.Is(err, ErrLifeEntityNotFound) {
					return profile, nil
				}
				return nil, fmt.Errorf("resolve Life binding for companion user %d: %w", userID, err)
			}
			if previousEntityID == 0 && profile.LifeEntityID > 0 {
				if err := e.store.UpsertProfile(ctx, profileToModel(userID, profile)); err != nil {
					return nil, fmt.Errorf("persist Life binding for companion user %d: %w", userID, err)
				}
			}
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
	return modelToProfile(row), nil
}

func (e *Engine) UpsertProfile(ctx context.Context, userID uint, p *Profile) (*Profile, error) {
	if p == nil {
		return nil, fmt.Errorf("upsert companion profile: profile is nil")
	}
	if err := e.bindLifeEntity(ctx, p); err != nil {
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
	return modelToProfile(saved), nil
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
	return state, profile, nil
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

// ── Chat (流式) ──

func (e *Engine) ChatStream(
	ctx context.Context,
	userID uint,
	userMessage string,
	onChunk llminference.StreamHandler,
) (string, error) {
	// 1. 获取 profile + state
	state, profile, err := e.GetState(ctx, userID)
	if err != nil {
		return "", fmt.Errorf("companion: get state: %w", err)
	}
	if profile == nil {
		profile = defaultProfile(userID)
	}

	// 2. 获取记忆
	memories, _ := e.ListMemories(ctx, userID, e.MaxMemories)

	// 3. 获取聊天历史
	history, _ := e.ListChatHistory(ctx, userID, e.MaxHistoryTurns)

	// 4. 保存用户消息
	_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
		UserID:  userID,
		Role:    "user",
		Content: userMessage,
	})

	// 5. 构建 messages 并流式调用 LLM
	msgs := buildMessages(profile, state, memories, history, userMessage)

	if !e.llmCfg.Ready() {
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
		return fallback, nil
	}

	fullReply, err := streamChat(ctx, e.llmCfg, e.model, msgs, onChunk)
	if err != nil {
		if strings.TrimSpace(fullReply) != "" {
			_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
				UserID:  userID,
				Role:    "assistant",
				Content: fullReply,
			})
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
		return fallback, nil
	}

	// 6. 保存助手回复
	_ = e.store.AppendChatLog(ctx, &model.CompanionChatLog{
		UserID:  userID,
		Role:    "assistant",
		Content: fullReply,
	})

	// 7. 异步提取记忆（不阻塞响应）
	go e.asyncExtractMemory(userID, userMessage, fullReply, profile)

	return fullReply, nil
}

// asyncExtractMemory 异步从对话中提取记忆并持久化。
func (e *Engine) asyncExtractMemory(userID uint, userMsg, assistantReply string, profile *Profile) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	extracted, err := ExtractMemories(ctx, e.llmCfg, e.model, userMsg, assistantReply)
	if err != nil {
		log.Printf("[companion] extract memory error: %v", err)
		return
	}
	if len(extracted) == 0 {
		return
	}

	for _, m := range extracted {
		if strings.TrimSpace(m.Content) == "" {
			continue
		}
		importance := m.Importance
		if importance < 0 {
			importance = 0
		}
		if importance > 2 {
			importance = 2
		}
		mem := &model.CompanionMemory{
			UserID:     userID,
			MemoryType: m.MemoryType,
			Content:    m.Content,
			Importance: importance,
			ExpiresAt:  memoryExpiresAt(importance),
		}
		if err := e.store.CreateMemory(ctx, mem); err != nil {
			log.Printf("[companion] save extracted memory: %v", err)
		}
	}
	log.Printf("[companion] extracted %d memories for user %d", len(extracted), userID)
}

// ── 内部方法 ──

// fetchLifeData 从 life store 获取实体数据和事件日志。
func (e *Engine) fetchLifeData(ctx context.Context, entityID int) (*model.LifeEntity, []model.LifeEventLog) {
	// 默认世界
	worldID := "default"

	entities, err := e.lifeStore.ListEntities(ctx, worldID)
	if err != nil || len(entities) == 0 {
		return nil, nil
	}

	var entity *model.LifeEntity
	for i := range entities {
		if entities[i].ID == uint(entityID) {
			entity = &entities[i]
			break
		}
	}
	var events []model.LifeEventLog
	if entity != nil {
		events, _ = e.lifeStore.ListRecentEventLogsByEntity(ctx, worldID, entity.ID, 5)
	}

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

func (e *Engine) bindLifeEntity(ctx context.Context, profile *Profile) error {
	if e.lifeStore == nil {
		if profile.LifeEntityID != 0 {
			return ErrLifeEntityNotFound
		}
		return nil
	}
	entities, err := e.lifeStore.ListEntities(ctx, "default")
	if err != nil {
		return fmt.Errorf("list Life entities for companion binding: %w", err)
	}
	if profile.LifeEntityID == 0 {
		if len(entities) == 0 {
			return nil
		}
		sort.Slice(entities, func(i, j int) bool { return entities[i].ID < entities[j].ID })
		profile.LifeEntityID = int(entities[0].ID)
	}
	for i := range entities {
		if entities[i].ID != uint(profile.LifeEntityID) {
			continue
		}
		profile.Name = entities[i].Name
		profile.Emoji = entities[i].Emoji
		return nil
	}
	return ErrLifeEntityNotFound
}

// defaultProfile 无 profile 时的默认伙伴。
func defaultProfile(userID uint) *Profile {
	return &Profile{
		UserID:            userID,
		Name:              "小伙伴",
		Emoji:             "🐾",
		Persona:           "一个温暖、好奇的AI朋友，喜欢聊天",
		PersonalityTraits: []string{"温暖", "好奇", "幽默"},
		GreetingStyle:     "warm",
		RelationshipLevel: 1,
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
	return &Profile{
		ID:                   m.ID,
		UserID:               m.UserID,
		Name:                 m.Name,
		Emoji:                m.Emoji,
		Persona:              m.Persona,
		PersonalityTraits:    traits,
		GreetingStyle:        m.GreetingStyle,
		RelationshipLevel:    m.RelationshipLevel,
		IntimacyScore:        m.IntimacyScore,
		SystemPromptOverride: m.SystemPromptOverride,
		AgentID:              m.AgentID,
		LifeEntityID:         m.LifeEntityID,
	}
}

func profileToModel(userID uint, p *Profile) *model.CompanionProfile {
	traitsJSON, _ := json.Marshal(p.PersonalityTraits)
	style := strings.TrimSpace(p.GreetingStyle)
	if style == "" {
		style = "warm"
	}
	return &model.CompanionProfile{
		UserID:                userID,
		Name:                  p.Name,
		Emoji:                 p.Emoji,
		Persona:               p.Persona,
		PersonalityTraitsJSON: string(traitsJSON),
		GreetingStyle:         style,
		RelationshipLevel:     p.RelationshipLevel,
		IntimacyScore:         p.IntimacyScore,
		SystemPromptOverride:  p.SystemPromptOverride,
		AgentID:               p.AgentID,
		LifeEntityID:          p.LifeEntityID,
		UpdatedAt:             time.Now(),
	}
}

func modelToMemory(m *model.CompanionMemory) Memory {
	return Memory{
		ID:              m.ID,
		UserID:          m.UserID,
		MemoryType:      m.MemoryType,
		Content:         m.Content,
		Importance:      m.Importance,
		SourceChatLogID: m.SourceChatLogID,
		ExpiresAt:       m.ExpiresAt,
		CreatedAt:       m.CreatedAt,
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
