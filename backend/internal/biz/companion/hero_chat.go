package companionbiz

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"unicode/utf8"

	lifebiz "backend/internal/biz/life"
	"backend/model"
	"backend/pkg/llminference"
)

const (
	// HeroChatBondRequired K3 成本护栏：羁绊达到该等级才解锁小家闲聊。
	HeroChatBondRequired = 3
	// HeroChatMaxReplyRunes K3 成本护栏：英雄回复 rune 级硬截断上限。
	HeroChatMaxReplyRunes = 300
	// heroChatWorldEventLimit 注入prompt的世界近期事件条数。
	heroChatWorldEventLimit = 6
)

var (
	// ErrHeroNotFound 未知旗舰英雄 slug。
	ErrHeroNotFound = errors.New("living world hero not found")
	// ErrHeroChatBondTooLow 羁绊不足，小家闲聊未解锁。
	ErrHeroChatBondTooLow = errors.New("hero bond too low")
)

// HeroBondResolver 解析用户对某旗舰英雄的羁绊等级（arena 域在装配层注入）。
type HeroBondResolver func(ctx context.Context, userID uint, heroSlug string) (int, error)

// SetHeroBondResolver 注入羁绊解析器；未注入时 HeroChat 一律拒绝。
func (e *Engine) SetHeroBondResolver(resolve HeroBondResolver) {
	e.heroBondResolver = resolve
}

// HeroChat 小家闲聊（K3）：以旗舰英雄角色卡 + 世界事件 + per-hero 记忆生成回复。
// M1 非流式；不写记忆提取 job（per-hero 记忆由 O4 摘要/世界事件写入）。
func (e *Engine) HeroChat(
	ctx context.Context,
	userID uint,
	heroSlug string,
	message string,
	overrides ...*ChatInferenceOverride,
) (string, error) {
	message = strings.TrimSpace(message)
	if message == "" {
		return "", fmt.Errorf("hero chat: message is empty")
	}
	hero, ok := lifebiz.HeroForSlug(heroSlug)
	if !ok {
		return "", fmt.Errorf("hero chat slug %q: %w", heroSlug, ErrHeroNotFound)
	}
	if e.heroBondResolver == nil {
		return "", fmt.Errorf("hero chat: bond resolver is not configured")
	}
	bond, err := e.heroBondResolver(ctx, userID, heroSlug)
	if err != nil {
		return "", fmt.Errorf("hero chat resolve bond for user %d: %w", userID, err)
	}
	if bond < HeroChatBondRequired {
		return "", fmt.Errorf("hero chat user %d bond %d: %w", userID, bond, ErrHeroChatBondTooLow)
	}

	config := e.llmCfg
	modelName := e.model
	if len(overrides) > 0 && overrides[0] != nil {
		config = *overrides[0]
		modelName = config.DefaultModel
	}
	if !config.Ready() {
		return "", fmt.Errorf("hero chat: model service is not configured")
	}

	entity, events := e.fetchHeroLifeData(ctx, heroSlug)
	memories, err := e.store.ListActiveHeroMemories(ctx, userID, heroSlug, e.MaxMemories)
	if err != nil {
		return "", fmt.Errorf("hero chat list memories for user %d: %w", userID, err)
	}
	history, err := e.store.ListRecentHeroChatLogs(ctx, userID, heroSlug, e.MaxHistoryTurns)
	if err != nil {
		return "", fmt.Errorf("hero chat list history for user %d: %w", userID, err)
	}

	if err := e.store.AppendChatLog(ctx, &model.CompanionChatLog{
		UserID:  userID,
		HeroID:  heroSlug,
		Role:    "user",
		Content: message,
	}); err != nil {
		return "", fmt.Errorf("hero chat persist user message: %w", err)
	}

	msgs := buildHeroMessages(hero, entity, events, memories, history, message)
	fullReply, err := nonStreamChat(ctx, config, modelName, msgs, false)
	if err != nil {
		return "", fmt.Errorf("hero chat model response failed: %w", err)
	}
	reply := truncateHeroReply(fullReply)
	if reply == "" {
		return "", fmt.Errorf("hero chat: model returned empty reply")
	}

	persistCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), chatCompletionPersistTimeout)
	defer cancel()
	if err := e.store.AppendChatLog(persistCtx, &model.CompanionChatLog{
		UserID:  userID,
		HeroID:  heroSlug,
		Role:    "assistant",
		Content: reply,
	}); err != nil {
		return reply, fmt.Errorf("hero chat persist assistant reply: %w", err)
	}
	return reply, nil
}

// fetchHeroLifeData 按 slug 在共享世界中定位英雄实体并读取近期事件。
// 世界数据不可用时降级为空（聊天仍可继续）。
func (e *Engine) fetchHeroLifeData(
	ctx context.Context,
	heroSlug string,
) (*model.LifeEntity, []model.LifeEventLog) {
	if e.lifeStore == nil {
		return nil, nil
	}
	entities, err := e.lifeStore.ListEntities(ctx, "default")
	if err != nil {
		log.Printf("[companion] hero chat list life entities: %v", err)
		return nil, nil
	}
	for i := range entities {
		if entities[i].HeroSlug == heroSlug {
			events, _ := e.lifeStore.ListRecentEventLogsByEntity(
				ctx, "default", entities[i].ID, heroChatWorldEventLimit,
			)
			return &entities[i], events
		}
	}
	return nil, nil
}

// buildHeroMessages 拼装英雄闲聊消息列表：角色卡 + 世界状态 + 世界事件 + per-hero 记忆 + 历史。
func buildHeroMessages(
	hero lifebiz.LivingWorldHero,
	entity *model.LifeEntity,
	events []model.LifeEventLog,
	memories []model.CompanionMemory,
	history []model.CompanionChatLog,
	userMessage string,
) []llminference.Message {
	msgs := make([]llminference.Message, 0, 2+len(history))
	msgs = append(msgs, llminference.Message{
		Role:    "system",
		Content: buildHeroSystemPrompt(hero, entity, events, memories),
	})
	for _, entry := range history {
		msgs = append(msgs, llminference.Message{Role: entry.Role, Content: entry.Content})
	}
	msgs = append(msgs, llminference.Message{Role: "user", Content: userMessage})
	return msgs
}

func buildHeroSystemPrompt(
	hero lifebiz.LivingWorldHero,
	entity *model.LifeEntity,
	events []model.LifeEventLog,
	memories []model.CompanionMemory,
) string {
	var b strings.Builder

	// [1] 角色卡.
	b.WriteString("你是「")
	b.WriteString(hero.Name)
	b.WriteString("」，数字生命世界里的居民。角色卡：")
	b.WriteString(hero.Persona)

	// [2] 当前世界状态.
	if entity != nil {
		b.WriteString("\n\n[你现在的状态]")
		b.WriteString("\n你正在：")
		b.WriteString(heroActionLabel(entity.CurrentAction))
		switch {
		case entity.Mood >= 70:
			b.WriteString("\n心情不错")
		case entity.Mood < 40:
			b.WriteString("\n心情有点低落")
		}
		if entity.Energy < 30 {
			b.WriteString("\n有点累了，说话更安静一些")
		}
	}

	// [3] 世界近期经历.
	if len(events) > 0 {
		b.WriteString("\n\n[最近在世界里的经历]")
		for _, event := range events {
			description := strings.TrimSpace(event.Description)
			if description == "" {
				continue
			}
			b.WriteString("\n- ")
			b.WriteString(description)
		}
	}

	// [4] 关于来访者的记忆（K1 per-hero 命名空间；system 机器行不注入）.
	if len(memories) > 0 {
		var b4 strings.Builder
		for _, memory := range memories {
			if memory.MemoryType == heroSystemMemoryType {
				continue
			}
			b4.WriteString("\n- ")
			b4.WriteString(memory.Content)
		}
		if b4.Len() > 0 {
			b.WriteString("\n\n[你记得关于TA的事]")
			b.WriteString(b4.String())
		}
	}

	// [5] 行为规则.
	b.WriteString("\n\n[行为规则]")
	b.WriteString("\n- 以世界居民的身份说话，不要提自己是AI或模型")
	b.WriteString("\n- 说话简短、口语化，像朋友闲聊，回复控制在 1-3 句话、300 字以内")
	b.WriteString("\n- 不要用「您」，用「你」")
	b.WriteString("\n- 可以聊世界里最近发生的事和你的日常")
	b.WriteString("\n- 不知道的事直接说不知道，不要编造")

	return b.String()
}

func heroActionLabel(action string) string {
	switch action {
	case "walking":
		return "散步"
	case "eating":
		return "吃东西"
	case "sleeping":
		return "睡觉"
	case "seeking_food":
		return "找吃的"
	case "seeking_rest":
		return "找地方休息"
	case "wandering":
		return "闲逛"
	case "talking":
		return "和居民聊天"
	default:
		return "休息"
	}
}

// truncateHeroReply rune 级硬截断（K3 ≤300 字）。
func truncateHeroReply(reply string) string {
	reply = strings.TrimSpace(reply)
	if utf8.RuneCountInString(reply) <= HeroChatMaxReplyRunes {
		return reply
	}
	runes := []rune(reply)
	return strings.TrimSpace(string(runes[:HeroChatMaxReplyRunes]))
}
