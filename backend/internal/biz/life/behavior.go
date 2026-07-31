package lifebiz

import (
	"math"
	"math/rand"

	"backend/model"
)

const (
	hungerDecayRate = 0.8
	energyDecayRate = 0.45
	moodDecayRate   = 0.18
	sleepRecovery   = 1.4
	wanderMoodBoost = 0.35
	idleRecovery    = 0.18
)

func decayAttributes(e *model.LifeEntity) {
	maxStat := GetMaxStat(e.GrowthStage)
	e.Hunger = clamp(e.Hunger-ApplyGrowthDecayMultiplier(e.GrowthStage, hungerDecayRate), 0, maxStat)
	e.Energy = clamp(e.Energy-ApplyGrowthDecayMultiplier(e.GrowthStage, energyDecayRate), 0, maxStat)
	e.Mood = clamp(e.Mood-ApplyGrowthDecayMultiplier(e.GrowthStage, moodDecayRate), 0, maxStat)
}

func applyEnvironmentEffects(e *model.LifeEntity, cell *WorldCell) {
	if e == nil || cell == nil {
		return
	}
	if cell.Danger > 35 {
		e.Mood = clamp(e.Mood-0.9, 0, 100)
		e.Energy = clamp(e.Energy-0.3, 0, 100)
	}
	if !cell.Habitable {
		e.Mood = clamp(e.Mood-0.6, 0, 100)
	}
	if cell.Moisture > 75 {
		e.Mood = clamp(e.Mood+0.2, 0, 100)
	}
}

func shouldDie(e *model.LifeEntity, cell *WorldCell) bool {
	if e == nil {
		return false
	}
	// 更贴近「长期照料」：仅在极端衰竭时消亡，避免稍低状态就消失。
	if e.Hunger <= 0 && e.Energy <= 5 {
		return true
	}
	if e.Energy <= 0 && e.Hunger <= 5 {
		return true
	}
	if cell != nil && cell.Danger > 96 && rand.Float64() < 0.03 {
		return true
	}
	return false
}

func decideAction(e *model.LifeEntity) LifeAction {
	if e.Energy < 15 {
		return ActionSleeping
	}
	if e.Hunger < 26 && e.Energy > 18 {
		return ActionSeekingFood
	}
	if e.Mood < 28 {
		return ActionWandering
	}
	if rand.Float64() < 0.18 {
		return ActionWalking
	}
	return ActionIdle
}

// decideActionWithRelations 关系感知的行为决策
func decideActionWithRelations(e *model.LifeEntity, entities map[uint]*model.LifeEntity, rels []*model.LifeRelationship) LifeAction {
	// 基础需求优先
	if e.Energy < 15 {
		return ActionSleeping
	}
	if e.Hunger < 26 && e.Energy > 18 {
		return ActionSeekingFood
	}

	// 有对手在附近 → 远离对手
	rivalID, rivalDist := FindNearbyRival(e, entities, rels)
	if rivalID > 0 && rivalDist < 120 {
		rival := entities[rivalID]
		if rival != nil {
			// 向远离对手的方向移动
			dx := e.PositionX - rival.PositionX
			dy := e.PositionY - rival.PositionY
			dist := math.Sqrt(dx*dx + dy*dy)
			if dist > 0 {
				e.PositionX = clamp(e.PositionX+(dx/dist)*30, 0, worldWidth)
				e.PositionY = clamp(e.PositionY+(dy/dist)*30, 0, worldHeight)
			}
			return ActionWalking
		}
	}

	// 有朋友/伴侣在附近 → 倾向于走向对方
	friendID, friendDist := FindNearbyFriend(e, entities, rels)
	if friendID > 0 && friendDist > 40 && friendDist < 200 {
		friend := entities[friendID]
		if friend != nil {
			// 向朋友移动
			dx := friend.PositionX - e.PositionX
			dy := friend.PositionY - e.PositionY
			dist := math.Sqrt(dx*dx + dy*dy)
			if dist > 0 {
				e.PositionX = clamp(e.PositionX+(dx/dist)*25, 0, worldWidth)
				e.PositionY = clamp(e.PositionY+(dy/dist)*25, 0, worldHeight)
			}
			e.Mood = clamp(e.Mood+0.3, 0, 100)
			return ActionTalking
		}
	}

	// 低情绪时寻求漫游
	if e.Mood < 28 {
		return ActionWandering
	}
	if rand.Float64() < 0.18 {
		return ActionWalking
	}
	return ActionIdle
}

// decideActionWithInteraction 在基础行为决策上增加物种互动（食物链/玩耍）
// Feature Flag: 通过 interactionEnabled 参数控制，关闭时回退到 decideActionWithRelations
func decideActionWithInteraction(
	e *model.LifeEntity,
	entities map[uint]*model.LifeEntity,
	rels []*model.LifeRelationship,
	interactionEnabled bool,
) LifeAction {
	// 基础行为（现有逻辑）
	baseAction := decideActionWithRelations(e, entities, rels)

	if !interactionEnabled {
		return baseAction
	}

	// 1. 食物链检查：附近是否有捕食者
	for _, other := range entities {
		if other.ID == e.ID || !other.IsAlive {
			continue
		}
		dx := e.PositionX - other.PositionX
		dy := e.PositionY - other.PositionY
		dist := math.Sqrt(dx*dx + dy*dy)
		if dist < 80 && IsPredatorOf(other.Emoji, e.Emoji) {
			return ActionFleeing // 发现捕食者，逃跑！
		}
	}

	// 2. 玩耍：无威胁 + 情绪 > 60 + 有朋友在场 → 20% 概率玩耍
	if baseAction == ActionIdle || baseAction == ActionWalking {
		if e.Mood > 60 {
			friendID, _ := FindNearbyFriend(e, entities, rels)
			if friendID > 0 {
				if rand.Float64() < 0.20 {
					return ActionPlaying
				}
			}
		}
	}

	return baseAction
}

func applyAction(e *model.LifeEntity, action LifeAction, cell *WorldCell) {
	e.CurrentAction = string(action)

	switch action {
	case ActionSleeping:
		e.Energy = clamp(e.Energy+sleepRecovery, 0, 100)
	case ActionWandering:
		e.Mood = clamp(e.Mood+wanderMoodBoost, 0, 100)
		e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*60, 0, worldWidth)
		e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*60, 0, worldHeight)
	case ActionWalking:
		e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*90, 0, worldWidth)
		e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*90, 0, worldHeight)
		e.Energy = clamp(e.Energy-0.25, 0, 100)
	case ActionSeekingFood:
		e.Energy = clamp(e.Energy-0.3, 0, 100)
		if cell != nil && cell.Food > 8 {
			consumed := minFloat(18, cell.Food)
			cell.Food = clamp(cell.Food-consumed, 0, maxCellFood)
			e.Hunger = clamp(e.Hunger+consumed*1.4, 0, 100)
			e.CurrentAction = string(ActionEating)
		} else {
			e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*100, 0, worldWidth)
			e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*100, 0, worldHeight)
		}
	case ActionSeekingRest:
		e.Energy = clamp(e.Energy-0.2, 0, 100)
		if cell != nil && cell.Habitable && cell.Danger < 20 {
			e.Energy = clamp(e.Energy+18, 0, 100)
			e.CurrentAction = string(ActionSleeping)
		}
	case ActionTalking:
		e.Mood = clamp(e.Mood+0.5, 0, 100)
	case ActionEating:
		e.Hunger = clamp(e.Hunger+12, 0, 100)
	case ActionIdle:
		e.Hunger = clamp(e.Hunger+idleRecovery, 0, 100)
		e.Energy = clamp(e.Energy+idleRecovery*0.5, 0, 100)
		e.Mood = clamp(e.Mood+idleRecovery*0.3, 0, 100)
	case ActionFleeing:
		// 逃跑：消耗 energy，向随机方向快速移动
		e.Energy = clamp(e.Energy-3, 0, 100)
		e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*120, 0, worldWidth)
		e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*120, 0, worldHeight)
	case ActionPlaying:
		// 玩耍：提升情绪，轻微消耗能量
		maxStat := GetMaxStat(e.GrowthStage)
		e.Mood = clamp(e.Mood+5, 0, maxStat)
		e.Energy = clamp(e.Energy-1, 0, 100)
	}
}

func clamp(v, min, max float64) float64 {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}

func minFloat(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
