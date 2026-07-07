package lifebiz

import (
	"context"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

// gridPersistInterval 每 N 个 tick 持久化一次生态网格
const gridPersistInterval = 10

// RunLifeTick executes one simulation tick.
func RunLifeTick(ctx context.Context, engine *LifeEngine) {
	oldSnap := engine.cache.Get(engine.config.WorldName)
	if oldSnap == nil {
		oldSnap = engine.initWorld(ctx)
		engine.cache.Set(engine.config.WorldName, oldSnap)
	}

	// 构建新的实体副本（避免并发读写竞争）
	mutableEntities := make(map[uint]*model.LifeEntity, len(oldSnap.Entities))
	var maxEntityID uint
	for k, v := range oldSnap.Entities {
		cp := *v
		mutableEntities[k] = &cp
		if k > maxEntityID {
			maxEntityID = k
		}
	}

	// 复用或创建网格
	var grid *WorldGrid
	if oldSnap.Grid != nil {
		// 深拷贝网格，避免修改旧快照
		gridCopy := *oldSnap.Grid
		cellsCopy := make([][]WorldCell, len(oldSnap.Grid.Cells))
		for y, row := range oldSnap.Grid.Cells {
			rowCopy := make([]WorldCell, len(row))
			copy(rowCopy, row)
			cellsCopy[y] = rowCopy
		}
		gridCopy.Cells = cellsCopy
		grid = &gridCopy
	} else {
		grid = newWorldGrid(engine.config)
	}
	updateWorldEcology(grid)

	var entityDiffs []EntityDiff
	var eventDiffs []EventDiff
	var removedEntityIDs []uint
	birthCount := 0
	deathCount := 0

	for id, entity := range mutableEntities {
		if entity == nil {
			continue
		}

		decayAttributes(entity)

		cellX, cellY := worldCellForEntity(grid, entity)
		cell := &grid.Cells[cellY][cellX]
		applyEnvironmentEffects(entity, cell)

		if shouldDie(entity, cell) {
			entity.CurrentAction = string(ActionDying)
			evt := &model.LifeEventLog{
				WorldID:     engine.config.WorldName,
				EntityID:    entity.ID,
				EntityType:  entity.Name,
				EventType:   "death",
				Description: entity.Name + " 在生态压力中消亡",
				PositionX:   entity.PositionX,
				PositionY:   entity.PositionY,
				CreatedAt:   time.Now(),
			}
			engine.persistence.EnqueueEvent(evt)
			eventDiffs = append(eventDiffs, EventDiff{
				EntityID:   entity.ID,
				EntityType: entity.Name,
				EventType:  "death",
				Desc:       evt.Description,
				PositionX:  entity.PositionX,
				PositionY:  entity.PositionY,
			})
			// Bug1: 通过 PersistenceWriter 入队软删除，确保 DB 中标记 is_alive=false
			engine.persistence.EnqueueDeleteEntity(entity.ID)
			// Bug2: 收集死亡实体 ID，供前端感知并移除
			removedEntityIDs = append(removedEntityIDs, entity.ID)
			delete(mutableEntities, id)
			deathCount++
			continue
		}

		oldAction := entity.CurrentAction
		newAction := decideAction(entity)
		applyAction(entity, newAction, cell)
		entity.LastActionAt = time.Now()
		entity.UpdatedAt = time.Now()

		entityDiffs = append(entityDiffs, EntityDiff{
			ID:            entity.ID,
			Name:          entity.Name,
			Emoji:         entity.Emoji,
			Hunger:        entity.Hunger,
			Energy:        entity.Energy,
			Mood:          entity.Mood,
			CurrentAction: LifeAction(entity.CurrentAction),
			PositionX:     entity.PositionX,
			PositionY:     entity.PositionY,
		})

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

		maxEntityID++
		if child := maybeSpawnOffspring(engine.config.WorldName, mutableEntities, entity, maxEntityID); child != nil {
			now := time.Now()
			child.LastActionAt = now
			child.CreatedAt = now
			child.UpdatedAt = now
			child.IsAlive = true
			mutableEntities[child.ID] = child
			engine.persistence.EnqueueEntity(child)
			entityDiffs = append(entityDiffs, EntityDiff{
				ID:            child.ID,
				Name:          child.Name,
				Emoji:         child.Emoji,
				Hunger:        child.Hunger,
				Energy:        child.Energy,
				Mood:          child.Mood,
				CurrentAction: LifeAction(child.CurrentAction),
				PositionX:     child.PositionX,
				PositionY:     child.PositionY,
			})
			birthEvt := &model.LifeEventLog{
				WorldID:     engine.config.WorldName,
				EntityID:    child.ID,
				EntityType:  child.Name,
				EventType:   "birth",
				Description: child.Name + " 在世界中诞生",
				PositionX:   child.PositionX,
				PositionY:   child.PositionY,
				CreatedAt:   now,
			}
			engine.persistence.EnqueueEvent(birthEvt)
			eventDiffs = append(eventDiffs, EventDiff{
				EntityID:   child.ID,
				EntityType: child.Name,
				EventType:  "birth",
				Desc:       birthEvt.Description,
				PositionX:  child.PositionX,
				PositionY:  child.PositionY,
			})
			birthCount++
		}

		entityCopy := *entity
		engine.persistence.EnqueueEntity(&entityCopy)
	}

	newTickCount := oldSnap.TickCount + 1
	summary := computeWorldSummary(grid, mutableEntities, birthCount, deathCount)

	// Bug4: 构建全新的 WorldSnapshot，然后通过 cache.Set() 原子替换，避免并发读写竞争
	newSnap := &WorldSnapshot{
		World:     oldSnap.World,
		Entities:  mutableEntities,
		Grid:      grid,
		Summary:   summary,
		TickCount: newTickCount,
	}
	newSnap.World.TickCount = newTickCount
	engine.cache.Set(engine.config.WorldName, newSnap)

	// Bug3: 每 gridPersistInterval 个 tick 持久化一次生态网格
	if newTickCount%gridPersistInterval == 0 {
		if gridJSON, err := SerializeGrid(grid); err == nil && gridJSON != "" {
			engine.persistence.EnqueueGridPersist(engine.config.WorldName, gridJSON)
		} else if err != nil {
			moelog.Errorf("life: failed to serialize grid for persist: %v", err)
		}
	}

	engine.broadcastMu.RLock()
	fn := engine.broadcastFn
	engine.broadcastMu.RUnlock()
	if fn != nil && (len(entityDiffs) > 0 || len(eventDiffs) > 0 || len(removedEntityIDs) > 0 || newTickCount == 1) {
		fn(TickBroadcast{
			Type:    "life_state",
			WorldID: engine.config.WorldName,
			Tick:    newTickCount,
			Summary: summary,
			Changes: TickChanges{
				Entities:         entityDiffs,
				Events:           eventDiffs,
				RemovedEntityIDs: removedEntityIDs,
			},
		})
	}
}

func generateEventDesc(name string, action LifeAction) string {
	switch action {
	case ActionSleeping:
		return name + " 开始休息"
	case ActionSeekingFood:
		return name + " 开始寻找食物"
	case ActionEating:
		return name + " 找到了食物，正在进食"
	case ActionWandering:
		return name + " 在世界中漫游"
	case ActionWalking:
		return name + " 开始移动"
	case ActionSeekingRest:
		return name + " 在寻找安全角落"
	case ActionTalking:
		return name + " 正在互动"
	case ActionReproducing:
		return name + " 进入繁衍状态"
	case ActionDying:
		return name + " 生命接近终点"
	case ActionIdle:
		return name + " 暂时停下了行动"
	default:
		return name + " 正在活动"
	}
}

func (e *LifeEngine) initWorld(ctx context.Context) *WorldSnapshot {
	world, err := e.store.GetWorld(ctx, e.config.WorldName)
	if err != nil || world == nil {
		if err != nil {
			moelog.Warnf("life: failed to load world %q from DB: %v, creating new", e.config.WorldName, err)
		}
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

	// Bug3: 尝试从 DB 恢复生态网格，若无则重新生成
	var grid *WorldGrid
	if world.GridData != "" {
		restored, restoreErr := DeserializeGrid(world.GridData)
		if restoreErr != nil {
			moelog.Warnf("life: failed to restore grid from DB for world %q: %v, regenerating", e.config.WorldName, restoreErr)
			grid = newWorldGrid(e.config)
		} else {
			grid = restored
			moelog.Infof("life: restored grid from DB for world %q (%dx%d)", e.config.WorldName, grid.Width, grid.Height)
		}
	} else {
		grid = newWorldGrid(e.config)
	}

	summary := computeWorldSummary(grid, entityMap, 0, 0)
	return &WorldSnapshot{
		World:     *world,
		Entities:  entityMap,
		Grid:      grid,
		Summary:   summary,
		TickCount: world.TickCount,
	}
}

func createSeedEntities(worldID string) []*model.LifeEntity {
	seeds := []struct {
		name, emoji string
		x, y        float64
	}{
		{"小花", "🐰", 200, 300},
		{"时雨", "🦊", 800, 400},
		{"团子", "🐹", 500, 200},
		{"啾啾", "🐥", 640, 150},
		{"泡泡", "🐠", 300, 500},
		{"小眠", "🦌", 900, 600},
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
			IsAlive:       true,
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
