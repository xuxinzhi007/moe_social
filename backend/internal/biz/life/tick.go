package lifebiz

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

// recordableActions 仅记录有意义的行为切换事件，过滤日常低价值行为（walking/idle/sleeping/seeking_food/seeking_rest）
var recordableActions = map[LifeAction]bool{
	ActionEating:      true,
	ActionTalking:     true,
	ActionWandering:   true,
	ActionReproducing: true,
	ActionDying:       true,
}

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

	// 拷贝关系列表，避免并发问题
	currentRels := make([]*model.LifeRelationship, len(oldSnap.Relationships))
	for i, r := range oldSnap.Relationships {
		rc := *r
		currentRels[i] = &rc
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

	// 世界事件处理
	worldEventDiffs := engine.worldEventEngine.Step(grid, int(oldSnap.TickCount), func(evt *model.LifeEventLog) {
		evt.WorldID = engine.config.WorldName
		evt.Importance = eventImportance(evt.EventType)
		engine.persistence.EnqueueEvent(evt)
	})

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

		// 应用活跃效果（buff）
		if entity.ActiveEffectsJSON != "" {
			effects, _ := DeserializeActiveEffects(entity.ActiveEffectsJSON)
			if len(effects) > 0 {
				var remaining []ActiveEffect
				for _, eff := range effects {
					applyItemEffect(entity, eff.EffectKey, eff.EffectValue)
					eff.RemainingTicks--
					if eff.RemainingTicks > 0 {
						remaining = append(remaining, eff)
					}
				}
				entity.ActiveEffectsJSON, _ = SerializeActiveEffects(remaining)
			}
		}

		// 经验积累与年龄增长
		entity.Experience += 1.0
		entity.Age += 1

		// 成长检测
		if nextStage, shouldGrow := ShouldGrow(entity.GrowthStage, entity.Experience); shouldGrow {
			entity.GrowthStage = nextStage
			evt := &model.LifeEventLog{
				WorldID:     engine.config.WorldName,
				EntityID:    entity.ID,
				EntityType:  entity.Name,
				EventType:   "growth",
				Description: fmt.Sprintf("%s进入了%s期！", entity.Name, GrowthStageNames[nextStage]),
				PositionX:   entity.PositionX,
				PositionY:   entity.PositionY,
				CreatedAt:   time.Now(),
			}
			evt.Importance = eventImportance(evt.EventType)
			engine.persistence.EnqueueEvent(evt)
			eventDiffs = append(eventDiffs, EventDiff{
				EntityID:   entity.ID,
				EntityType: entity.Name,
				EventType:  "growth",
				Desc:       evt.Description,
				PositionX:  entity.PositionX,
				PositionY:  entity.PositionY,
			})
		}

		// 属性上限限制（根据成长阶段）
		maxStat := GetMaxStat(entity.GrowthStage)
		entity.Hunger = clamp(entity.Hunger, 0, maxStat)
		entity.Energy = clamp(entity.Energy, 0, maxStat)
		entity.Mood = clamp(entity.Mood, 0, maxStat)

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
			evt.Importance = eventImportance(evt.EventType)
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

		// 老年自然死亡概率
		if entity.GrowthStage == StageElderly {
			deathChance := 0.005 + float64(entity.Age-800)*0.00001
			if deathChance > 0 && rand.Float64() < deathChance {
				entity.CurrentAction = string(ActionDying)
				evt := &model.LifeEventLog{
					WorldID:     engine.config.WorldName,
					EntityID:    entity.ID,
					EntityType:  entity.Name,
					EventType:   "death",
					Description: entity.Name + " 因年迈而安详离世",
					PositionX:   entity.PositionX,
					PositionY:   entity.PositionY,
					CreatedAt:   time.Now(),
				}
				evt.Importance = eventImportance(evt.EventType)
				engine.persistence.EnqueueEvent(evt)
				eventDiffs = append(eventDiffs, EventDiff{
					EntityID:   entity.ID,
					EntityType: entity.Name,
					EventType:  "death",
					Desc:       evt.Description,
					PositionX:  entity.PositionX,
					PositionY:  entity.PositionY,
				})
				engine.persistence.EnqueueDeleteEntity(entity.ID)
				removedEntityIDs = append(removedEntityIDs, entity.ID)
				delete(mutableEntities, id)
				deathCount++
				continue
			}
		}

		oldAction := entity.CurrentAction
		newAction := decideActionWithRelations(entity, mutableEntities, currentRels)
		applyAction(entity, newAction, cell)
		entity.LastActionAt = time.Now()
		entity.UpdatedAt = time.Now()

		// 构建 ActiveEffectSummary（给前端展示 buff 图标）
		var effectSummaries []ActiveEffectSummary
		if entity.ActiveEffectsJSON != "" {
			if effects, _ := DeserializeActiveEffects(entity.ActiveEffectsJSON); len(effects) > 0 {
				for _, eff := range effects {
					if def, ok := engine.itemSystem.GetItemDefinition(eff.ItemID); ok {
						effectSummaries = append(effectSummaries, ActiveEffectSummary{
							ItemID:    eff.ItemID,
							Icon:      def.Icon,
							Name:      def.Name,
							Remaining: eff.RemainingTicks,
						})
					}
				}
			}
		}

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
			Age:           entity.Age,
			GrowthStage:   entity.GrowthStage,
			Experience:    entity.Experience,
			ActiveEffects: effectSummaries,
		})

		if newAction != LifeAction(oldAction) {
			// 仅记录有意义的行为切换，过滤 walking/idle/sleeping 等低价值事件
			if recordableActions[newAction] {
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
				evt.Importance = eventImportance(evt.EventType)
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
		}

		maxEntityID++
		if child := maybeSpawnOffspring(engine.config.WorldName, mutableEntities, entity, maxEntityID, currentRels); child != nil {
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
				Age:           child.Age,
				GrowthStage:   child.GrowthStage,
				Experience:    child.Experience,
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
			birthEvt.Importance = eventImportance(birthEvt.EventType)
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

	// 社交关系更新
	newRels, updatedRels, deletedRelIDs, socialEvents := engine.socialSystem.UpdateRelationships(
		engine.config.WorldName, mutableEntities, currentRels,
	)

	// 持久化新关系
	for _, r := range newRels {
		rc := *r
		engine.persistence.EnqueueRelationship(&rc)
	}
	// 持久化更新的关系
	for _, r := range updatedRels {
		rc := *r
		engine.persistence.EnqueueRelationship(&rc)
	}
	// 持久化删除的关系
	for _, id := range deletedRelIDs {
		engine.persistence.EnqueueDeleteRelationship(id)
	}

	// 记录社交事件
	var relDiffs []RelationshipDiff
	var removedRelDiffs []RemovedRelationship
	for _, evt := range socialEvents {
		evt.Importance = eventImportance(evt.EventType)
		engine.persistence.EnqueueEvent(evt)
		eventDiffs = append(eventDiffs, EventDiff{
			EntityID:   evt.EntityID,
			EntityType: evt.EntityType,
			EventType:  evt.EventType,
			Desc:       evt.Description,
			PositionX:  evt.PositionX,
			PositionY:  evt.PositionY,
		})
	}

	// 构建关系 diff 用于广播
	for _, r := range newRels {
		relDiffs = append(relDiffs, RelationshipDiff{
			EntityID:     r.EntityID,
			TargetID:     r.TargetID,
			RelationType: r.RelationType,
			Affinity:     r.Affinity,
		})
	}
	for _, r := range updatedRels {
		relDiffs = append(relDiffs, RelationshipDiff{
			EntityID:     r.EntityID,
			TargetID:     r.TargetID,
			RelationType: r.RelationType,
			Affinity:     r.Affinity,
		})
	}
	// 从 currentRels 中查找被删除关系的实体对
	for _, delID := range deletedRelIDs {
		for _, r := range currentRels {
			if r.ID == delID {
				removedRelDiffs = append(removedRelDiffs, RemovedRelationship{
					EntityID: r.EntityID,
					TargetID: r.TargetID,
				})
				break
			}
		}
	}

	// 构建当前 tick 后的完整关系列表（用于下一 tick）
	finalRels := buildFinalRelationships(currentRels, newRels, updatedRels, deletedRelIDs)

	newTickCount := oldSnap.TickCount + 1
	summary := computeWorldSummary(grid, mutableEntities, birthCount, deathCount)
	summary.Weather = grid.Weather
	summary.ActiveEvents = engine.worldEventEngine.ActiveEventDescriptions()

	// Bug4: 构建全新的 WorldSnapshot，然后通过 cache.Set() 原子替换，避免并发读写竞争
	newSnap := &WorldSnapshot{
		World:         oldSnap.World,
		Entities:      mutableEntities,
		Grid:          grid,
		Summary:       summary,
		TickCount:     newTickCount,
		Relationships: finalRels,
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
	if fn != nil && (len(entityDiffs) > 0 || len(eventDiffs) > 0 || len(removedEntityIDs) > 0 ||
		len(relDiffs) > 0 || len(removedRelDiffs) > 0 || len(worldEventDiffs) > 0 || newTickCount == 1) {
		fn(TickBroadcast{
			Type:    "life_state",
			WorldID: engine.config.WorldName,
			Tick:    newTickCount,
			Summary: summary,
			Changes: TickChanges{
				Entities:             entityDiffs,
				Events:               eventDiffs,
				RemovedEntityIDs:     removedEntityIDs,
				Relationships:        relDiffs,
				RemovedRelationships: removedRelDiffs,
				WorldEvents:          worldEventDiffs,
			},
		})
	}
}

// buildFinalRelationships 构建 tick 后的完整关系列表
func buildFinalRelationships(
	existing []*model.LifeRelationship,
	newRels []*model.LifeRelationship,
	updatedRels []*model.LifeRelationship,
	deletedIDs []uint,
) []*model.LifeRelationship {
	// 构建删除集合
	delSet := make(map[uint]struct{}, len(deletedIDs))
	for _, id := range deletedIDs {
		delSet[id] = struct{}{}
	}

	// 构建更新索引
	updateMap := make(map[uint]*model.LifeRelationship, len(updatedRels))
	for _, r := range updatedRels {
		updateMap[r.ID] = r
	}

	var result []*model.LifeRelationship

	// 保留未删除的旧关系（应用更新）
	for _, r := range existing {
		if _, deleted := delSet[r.ID]; deleted {
			continue
		}
		if updated, ok := updateMap[r.ID]; ok {
			result = append(result, updated)
		} else {
			result = append(result, r)
		}
	}

	// 添加新关系
	result = append(result, newRels...)

	return result
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

	// 加载现有社交关系
	rels, err := e.store.ListRelationshipsByWorld(ctx, e.config.WorldName)
	if err != nil {
		moelog.Warnf("life: failed to load relationships for world %q: %v", e.config.WorldName, err)
		rels = nil
	}

	summary := computeWorldSummary(grid, entityMap, 0, 0)
	return &WorldSnapshot{
		World:         *world,
		Entities:      entityMap,
		Grid:          grid,
		Summary:       summary,
		TickCount:     world.TickCount,
		Relationships: rels,
	}
}

func createSeedEntities(worldID string) []*model.LifeEntity {
	seeds := []struct {
		name, emoji string
		x, y        float64
		age         int
	}{
		{"小花", "🐰", 200, 300, 20},   // 幼年
		{"时雨", "🦊", 800, 400, 150},  // 少年
		{"团子", "🐹", 500, 200, 400},  // 成年
		{"啾啾", "🐥", 640, 150, 50},   // 幼年
		{"泡泡", "🐠", 300, 500, 250},  // 少年
		{"小眠", "🦌", 900, 600, 850},  // 老年
	}
	var result []*model.LifeEntity
	now := time.Now()
	for _, s := range seeds {
		stage := stageForAge(s.age)
		result = append(result, &model.LifeEntity{
			WorldID:       worldID,
			Name:          s.name,
			Emoji:         s.emoji,
			Hunger:        80,
			Energy:        80,
			Mood:          70,
			Age:           s.age,
			GrowthStage:   stage,
			Experience:    float64(s.age),
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

// stageForAge 根据年龄返回对应的成长阶段
func stageForAge(age int) string {
	switch {
	case age < 100:
		return StageJuvenile
	case age < 300:
		return StageAdolescent
	case age < 800:
		return StageAdult
	default:
		return StageElderly
	}
}
