package lifebiz

import (
	"context"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

// RunLifeTick executes one simulation tick.
func RunLifeTick(ctx context.Context, engine *LifeEngine) {
	snap := engine.cache.Get(engine.config.WorldName)
	if snap == nil {
		snap = engine.initWorld(ctx)
		engine.cache.Set(engine.config.WorldName, snap)
	}

	mutableEntities := make(map[uint]*model.LifeEntity, len(snap.Entities))
	var maxEntityID uint
	for k, v := range snap.Entities {
		cp := *v
		mutableEntities[k] = &cp
		if k > maxEntityID {
			maxEntityID = k
		}
	}

	if snap.Grid == nil {
		snap.Grid = newWorldGrid(engine.config)
	}
	updateWorldEcology(snap.Grid)

	var entityDiffs []EntityDiff
	var eventDiffs []EventDiff
	birthCount := 0
	deathCount := 0

	for id, entity := range mutableEntities {
		if entity == nil {
			continue
		}

		decayAttributes(entity)

		cellX, cellY := worldCellForEntity(snap.Grid, entity)
		cell := &snap.Grid.Cells[cellY][cellX]
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

	snap.Entities = mutableEntities
	snap.TickCount++
	snap.World.TickCount = snap.TickCount
	snap.Summary = computeWorldSummary(snap.Grid, snap.Entities, birthCount, deathCount)

	engine.broadcastMu.RLock()
	fn := engine.broadcastFn
	engine.broadcastMu.RUnlock()
	if fn != nil && (len(entityDiffs) > 0 || len(eventDiffs) > 0 || snap.TickCount == 1) {
		fn(TickBroadcast{
			Type:    "life_state",
			WorldID: engine.config.WorldName,
			Tick:    snap.TickCount,
			Summary: snap.Summary,
			Changes: TickChanges{
				Entities: entityDiffs,
				Events:   eventDiffs,
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

	grid := newWorldGrid(e.config)
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
