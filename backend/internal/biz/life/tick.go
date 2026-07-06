package lifebiz

import (
	"context"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

// RunLifeTick 执行单次 tick
func RunLifeTick(ctx context.Context, engine *LifeEngine) {
	snap := engine.cache.Get(engine.config.WorldName)
	if snap == nil {
		// 首次运行，从 DB 加载或初始化
		snap = engine.initWorld(ctx)
		engine.cache.Set(engine.config.WorldName, snap)
	}

	// 创建 mutable copy，避免与 sendSnapshot 并发读写（data race）
	mutableEntities := make(map[uint]*model.LifeEntity, len(snap.Entities))
	for k, v := range snap.Entities {
		cp := *v
		mutableEntities[k] = &cp
	}

	var entityDiffs []EntityDiff
	var eventDiffs []EventDiff

	for _, entity := range mutableEntities {
		// 1. 需求衰减
		decayAttributes(entity)

		// 2. 行为决策
		newAction := decideAction(entity)
		oldAction := entity.CurrentAction

		// 3. 执行行为效果
		applyAction(entity, newAction)
		entity.LastActionAt = time.Now()
		entity.UpdatedAt = time.Now()

		// 4. 构建增量 diff
		diff := EntityDiff{
			ID:            entity.ID,
			Name:          entity.Name,
			Emoji:         entity.Emoji,
			Hunger:        entity.Hunger,
			Energy:        entity.Energy,
			Mood:          entity.Mood,
			CurrentAction: LifeAction(entity.CurrentAction),
			PositionX:     entity.PositionX,
			PositionY:     entity.PositionY,
		}
		entityDiffs = append(entityDiffs, diff)

		// 5. 生成事件日志（仅行为变化时）
		if newAction != LifeAction(oldAction) {
			evt := &model.LifeEventLog{
				WorldID:     engine.config.WorldName,
				EntityID:    entity.ID,
				EntityType:  entity.Name,
				EventType:   string(newAction),
				Description: generateEventDesc(entity.Name, newAction),
				PositionX:   entity.PositionX,
				PositionY:   entity.PositionY,
				CreatedAt:   time.Now(),
			}
			engine.persistence.EnqueueEvent(evt)
			eventDiffs = append(eventDiffs, EventDiff{
				EntityID:   entity.ID,
				EntityType: entity.Name,
				EventType:  string(newAction),
				Desc:       evt.Description,
				PositionX:  entity.PositionX,
				PositionY:  entity.PositionY,
			})
		}

		// 6. 入队持久化
		entityCopy := *entity
		engine.persistence.EnqueueEntity(&entityCopy)
	}

	// 7. tick 结束后，将 mutableEntities 写回 snap（此时 tick 独占 snap）
	snap.Entities = mutableEntities

	// 8. 更新 tick count
	snap.TickCount++
	snap.World.TickCount = snap.TickCount

	// 9. 广播（通过 RWMutex 安全读取 broadcastFn）
	engine.broadcastMu.RLock()
	fn := engine.broadcastFn
	engine.broadcastMu.RUnlock()
	if fn != nil && (len(entityDiffs) > 0 || len(eventDiffs) > 0) {
		msg := TickBroadcast{
			Type:    "life_state",
			WorldID: engine.config.WorldName,
			Tick:    snap.TickCount,
			Changes: TickChanges{
				Entities: entityDiffs,
				Events:   eventDiffs,
			},
		}
		fn(msg)
	}
}

// generateEventDesc 生成事件描述
func generateEventDesc(name string, action LifeAction) string {
	switch action {
	case ActionSleeping:
		return name + " 开始休息"
	case ActionSeekingFood:
		return name + " 开始寻找食物"
	case ActionEating:
		return name + " 找到了食物，正在进食"
	case ActionWandering:
		return name + " 四处闲逛"
	case ActionWalking:
		return name + " 开始散步"
	case ActionSeekingRest:
		return name + " 开始寻找休息处"
	case ActionTalking:
		return name + " 正在交谈"
	case ActionIdle:
		return name + " 停下了动作"
	default:
		return name + " 在休息"
	}
}

// initWorld 首次运行时初始化世界
func (e *LifeEngine) initWorld(ctx context.Context) *WorldSnapshot {
	// 尝试从 DB 加载
	world, err := e.store.GetWorld(ctx, e.config.WorldName)
	if err != nil || world == nil {
		if err != nil {
			moelog.Warnf("life: failed to load world %q from DB: %v, creating new", e.config.WorldName, err)
		}
		// 创建新世界
		world = &model.LifeWorld{
			Name:      e.config.WorldName,
			IsRunning: true,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		if upsertErr := e.store.UpsertWorld(ctx, world); upsertErr != nil {
			moelog.Errorf("life: failed to upsert world: %v", upsertErr)
		}
	}

	entities, err := e.store.ListEntities(ctx, e.config.WorldName)
	if err != nil {
		moelog.Errorf("life: failed to list entities for world %q: %v", e.config.WorldName, err)
	}
	entityMap := make(map[uint]*model.LifeEntity, len(entities))
	for i := range entities {
		entityMap[entities[i].ID] = &entities[i]
	}

	// 如果没有实体，创建种子数据
	if len(entityMap) == 0 {
		seeds := createSeedEntities(e.config.WorldName)
		for _, s := range seeds {
			if err := e.store.UpsertEntity(ctx, s); err != nil {
				moelog.Errorf("life: failed to create seed entity %q: %v", s.Name, err)
				continue
			}
			entityMap[s.ID] = s
		}
	}

	return &WorldSnapshot{
		World:     *world,
		Entities:  entityMap,
		TickCount: world.TickCount,
	}
}

// createSeedEntities 创建初始种子实体（可爱动物）
func createSeedEntities(worldID string) []*model.LifeEntity {
	seeds := []struct {
		name, emoji string
		x, y        float64
	}{
		{"小花", "🐱", 200, 300},
		{"旺财", "🐶", 800, 400},
		{"团子", "🐰", 500, 200},
		{"啾啾", "🐦", 640, 150},
		{"泡泡", "🐠", 300, 500},
		{"小龟", "🐢", 900, 600},
	}
	var result []*model.LifeEntity
	now := time.Now()
	for _, s := range seeds {
		result = append(result, &model.LifeEntity{
			WorldID:       worldID,
			Name:          s.name,
			Emoji:         s.emoji,
			Hunger:        80,
			Energy:        80,
			Mood:          70,
			CurrentAction: string(ActionIdle),
			PositionX:     s.x,
			PositionY:     s.y,
			LastActionAt:  now,
			UpdatedAt:     now,
			CreatedAt:     now,
		})
	}
	return result
}
