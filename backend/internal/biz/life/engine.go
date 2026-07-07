package lifebiz

import (
	"context"
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
	store           Store
	cache           *WorldCache
	persistence     *PersistenceWriter
	socialSystem    *SocialSystem
	config          LifeConfig
	broadcastMu     sync.RWMutex
	broadcastFn     BroadcastFunc
	actionCooldowns map[uint]time.Time // 实体 ID→冷却到期时间
	cooldownMu      sync.Mutex
}

// NewLifeEngine 创建数字生命引擎
func NewLifeEngine(store Store, config LifeConfig, broadcastFn BroadcastFunc) *LifeEngine {
	engine := &LifeEngine{
		store:           store,
		cache:           NewWorldCache(),
		persistence:     NewPersistenceWriter(store, config),
		socialSystem:    NewSocialSystem(),
		config:          config,
		broadcastFn:     broadcastFn,
		actionCooldowns: make(map[uint]time.Time),
	}
	return engine
}

// StartLifeEngine 启动引擎 goroutine
func StartLifeEngine(ctx context.Context, e *LifeEngine) {
	// 启动持久化写入器
	e.persistence.Start(ctx)

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

// ActionResult 用户操作结果
type ActionResult struct {
	Success bool            `json:"success"`
	Message string          `json:"message"`
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
	e.persistence.EnqueueEvent(evt)

	return ActionResult{
		Success: true,
		Message: "用户" + desc,
		Entity:  entity,
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
