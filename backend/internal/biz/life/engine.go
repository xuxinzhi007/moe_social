package lifebiz

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

// BroadcastFunc 广播回调类型
type BroadcastFunc func(msg TickBroadcast)

// LifeEngine 数字生命引擎
type LifeEngine struct {
	store            Store
	cache            *WorldCache
	persistence      *PersistenceWriter
	socialSystem     *SocialSystem
	worldEventEngine *WorldEventEngine
	itemSystem       *ItemSystem
	config           LifeConfig
	broadcastMu      sync.RWMutex
	broadcastFn      BroadcastFunc
	actionCooldowns  map[uint]time.Time // 实体 ID→冷却到期时间
	cooldownMu       sync.Mutex
}

// NewLifeEngine 创建数字生命引擎
func NewLifeEngine(store Store, config LifeConfig, broadcastFn BroadcastFunc) *LifeEngine {
	engine := &LifeEngine{
		store:            store,
		cache:            NewWorldCache(),
		persistence:      NewPersistenceWriter(store, config),
		socialSystem:     NewSocialSystem(),
		worldEventEngine: NewWorldEventEngine(),
		itemSystem:       NewItemSystem(store),
		config:           config,
		broadcastFn:      broadcastFn,
		actionCooldowns:  make(map[uint]time.Time),
	}
	return engine
}

// StartLifeEngine 启动引擎 goroutine
func StartLifeEngine(ctx context.Context, e *LifeEngine) {
	// 启动持久化写入器
	e.persistence.Start(ctx)

	// 初始化种子道具
	if err := e.itemSystem.SeedItems(ctx); err != nil {
		moelog.Errorf("life: failed to seed items: %v", err)
	}

	go func() {
		defer func() {
			if r := recover(); r != nil {
				moelog.Errorf("life: LifeEngine panic recovered: %v", r)
			}
		}()
		ticker := time.NewTicker(e.config.TickInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				moelog.Infof("life: engine stopped for world %q", e.config.WorldName)
				return
			case <-ticker.C:
				tickCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
				RunLifeTick(tickCtx, e)
				cancel()
			}
		}
	}()
}

// SetBroadcastFunc 注入广播回调（可在运行时由 WS hub 注入）
func (e *LifeEngine) SetBroadcastFunc(fn BroadcastFunc) {
	e.broadcastMu.Lock()
	defer e.broadcastMu.Unlock()
	e.broadcastFn = fn
}

// GetWorldCache 暴露缓存供外部读取
func (e *LifeEngine) GetWorldCache() *WorldCache { return e.cache }

// GetConfig 获取配置
func (e *LifeEngine) GetConfig() LifeConfig { return e.config }

// GetStore 暴露 store 供外部读取
func (e *LifeEngine) GetStore() Store { return e.store }

// GetItemSystem 暴露道具系统供外部读取
func (e *LifeEngine) GetItemSystem() *ItemSystem { return e.itemSystem }

// ActionResult 用户操作结果
type ActionResult struct {
	Success bool              `json:"success"`
	Message string            `json:"message"`
	Entity  *model.LifeEntity `json:"entity,omitempty"`
}

// ApplyUserAction 对用户指定的实体执行操作（feed/pet/move）
func (e *LifeEngine) ApplyUserAction(worldName string, entityID uint, action string, params map[string]interface{}) ActionResult {
	// 冷却校验
	e.cooldownMu.Lock()
	if deadline, ok := e.actionCooldowns[entityID]; ok && time.Now().Before(deadline) {
		remaining := time.Until(deadline).Seconds()
		e.cooldownMu.Unlock()
		return ActionResult{Success: false, Message: fmt.Sprintf("action in cooldown, retry after %.0f seconds", remaining)}
	}
	e.cooldownMu.Unlock()

	snap := e.cache.Get(worldName)
	if snap == nil {
		return ActionResult{Success: false, Message: "world not initialized"}
	}

	entity, ok := snap.Entities[entityID]
	if !ok || entity == nil {
		return ActionResult{Success: false, Message: "entity not found"}
	}

	now := time.Now()

	switch action {
	case "feed":
		entity.Hunger = clamp(entity.Hunger+20, 0, 100)
		entity.Mood = clamp(entity.Mood+5, 0, 100)
		entity.UpdatedAt = now
	case "pet":
		entity.Mood = clamp(entity.Mood+15, 0, 100)
		entity.UpdatedAt = now
	case "move":
		x, okX := params["x"].(float64)
		y, okY := params["y"].(float64)
		if !okX || !okY {
			return ActionResult{Success: false, Message: "move requires x and y params"}
		}
		entity.PositionX = clamp(x, 0, worldWidth)
		entity.PositionY = clamp(y, 0, worldHeight)
		entity.CurrentAction = string(ActionWalking)
		entity.UpdatedAt = now
	default:
		return ActionResult{Success: false, Message: "unknown action: " + action}
	}

	// 设置冷却
	e.cooldownMu.Lock()
	e.actionCooldowns[entityID] = time.Now().Add(time.Duration(e.config.ActionCooldownSeconds) * time.Second)
	e.cooldownMu.Unlock()

	// 持久化更新
	entityCopy := *entity
	e.persistence.EnqueueEntity(&entityCopy)

	// 记录事件日志
	desc := actionVerb(action) + "了" + entity.Name
	evt := &model.LifeEventLog{
		WorldID:     worldName,
		EntityID:    entity.ID,
		EntityType:  entity.Name,
		EventType:   "user_" + action,
		Description: "用户" + desc,
		PositionX:   entity.PositionX,
		PositionY:   entity.PositionY,
		CreatedAt:   now,
	}
	evt.Importance = eventImportance(evt.EventType)
	e.persistence.EnqueueEvent(evt)

	return ActionResult{
		Success: true,
		Message: "用户" + desc,
		Entity:  entity,
	}
}

// maxActiveEffects 单个实体最大活跃 buff 数量
const maxActiveEffects = 5

// UseItem 对指定实体使用道具
func (e *LifeEngine) UseItem(worldName, userID string, entityID, itemID uint) error {
	// 1. 查道具定义
	item, ok := e.itemSystem.GetItemDefinition(itemID)
	if !ok {
		return errors.New("item not found")
	}

	// 2. 扣减背包
	ctx := context.Background()
	if err := e.store.DecrementInventory(ctx, userID, itemID); err != nil {
		return fmt.Errorf("inventory insufficient: %w", err)
	}

	// 3. 查找实体
	snap := e.cache.Get(worldName)
	if snap == nil {
		return errors.New("world not initialized")
	}
	entity, ok := snap.Entities[entityID]
	if !ok || entity == nil {
		return errors.New("entity not found")
	}

	now := time.Now()

	if item.DurationTicks > 0 {
		// 持续效果：加入 ActiveEffects
		effects, _ := DeserializeActiveEffects(entity.ActiveEffectsJSON)
		if len(effects) >= maxActiveEffects {
			return fmt.Errorf("active effects limit reached (%d/%d)", len(effects), maxActiveEffects)
		}
		effects = append(effects, ActiveEffect{
			ItemID:         itemID,
			EffectKey:      item.EffectKey,
			EffectValue:    item.EffectValue,
			RemainingTicks: item.DurationTicks,
		})
		effectsJSON, err := SerializeActiveEffects(effects)
		if err != nil {
			return fmt.Errorf("serialize effects: %w", err)
		}
		entity.ActiveEffectsJSON = effectsJSON
	} else {
		// 即时效果：直接修改属性
		applyItemEffect(entity, item.EffectKey, item.EffectValue)
	}
	entity.UpdatedAt = now

	// 持久化实体变更
	entityCopy := *entity
	e.persistence.EnqueueEntity(&entityCopy)

	// 4. 记录事件
	evt := &model.LifeEventLog{
		WorldID:     worldName,
		EntityID:    entityID,
		EntityType:  entity.Name,
		EventType:   "user_use_item",
		Description: fmt.Sprintf("对 %s 使用了 %s", entity.Name, item.Name),
		PositionX:   entity.PositionX,
		PositionY:   entity.PositionY,
		CreatedAt:   now,
		Importance:  1,
	}
	e.persistence.EnqueueEvent(evt)

	return nil
}

// applyItemEffect 对实体施加即时道具效果
func applyItemEffect(entity *model.LifeEntity, effectKey string, value float64) {
	switch effectKey {
	case "hunger":
		entity.Hunger = clamp(entity.Hunger+value, 0, 100)
	case "energy":
		entity.Energy = clamp(entity.Energy+value, 0, 100)
	case "mood":
		entity.Mood = clamp(entity.Mood+value, 0, 100)
	case "experience":
		entity.Experience += value
	case "all":
		entity.Hunger = clamp(entity.Hunger+value, 0, 100)
		entity.Energy = clamp(entity.Energy+value, 0, 100)
		entity.Mood = clamp(entity.Mood+value, 0, 100)
	}
}

func actionVerb(action string) string {
	switch action {
	case "feed":
		return "喂"
	case "pet":
		return "抚摸"
	case "move":
		return "移动"
	default:
		return "执行"
	}
}
