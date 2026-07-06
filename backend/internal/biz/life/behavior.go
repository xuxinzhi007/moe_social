package lifebiz

import (
	"math/rand"

	"backend/model"
)

// 每 tick 属性衰减速率
const (
	hungerDecayRate = 0.5 // 每 tick Hunger -= 0.5
	energyDecayRate = 0.3 // 每 tick Energy -= 0.3
	moodDecayRate   = 0.1 // 每 tick Mood -= 0.1
	sleepRecovery   = 1.0 // sleeping 时 Energy += 1.0/tick
	wanderMoodBoost = 0.3 // wandering 时 Mood += 0.3/tick
	idleRecovery    = 0.2 // idle 时各属性小幅恢复
)

// decayAttributes 需求衰减
func decayAttributes(e *model.LifeEntity) {
	e.Hunger = clamp(e.Hunger-hungerDecayRate, 0, 100)
	e.Energy = clamp(e.Energy-energyDecayRate, 0, 100)
	e.Mood = clamp(e.Mood-moodDecayRate, 0, 100)
}

// decideAction 基于当前状态决定行为
func decideAction(e *model.LifeEntity) LifeAction {
	// 优先级从高到低
	if e.Energy < 15 {
		return ActionSleeping
	}
	if e.Hunger < 20 && e.Energy > 30 {
		return ActionSeekingFood
	}
	if e.Mood < 30 {
		return ActionWandering
	}
	// 默认 idle，小概率随机走动
	if rand.Float64() < 0.15 {
		return ActionWalking
	}
	return ActionIdle
}

// applyAction 执行行为效果
func applyAction(e *model.LifeEntity, action LifeAction) {
	e.CurrentAction = string(action)
	switch action {
	case ActionSleeping:
		e.Energy = clamp(e.Energy+sleepRecovery, 0, 100)
	case ActionWandering:
		e.Mood = clamp(e.Mood+wanderMoodBoost, 0, 100)
		// 随机移动
		e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*60, 0, 1280)
		e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*60, 0, 720)
	case ActionWalking:
		e.PositionX = clamp(e.PositionX+(rand.Float64()-0.5)*80, 0, 1280)
		e.PositionY = clamp(e.PositionY+(rand.Float64()-0.5)*80, 0, 720)
	case ActionSeekingFood:
		e.Energy = clamp(e.Energy-0.2, 0, 100) // 移动消耗额外精力
		// 10% 概率找到食物
		if rand.Float64() < 0.1 {
			e.Hunger = clamp(e.Hunger+30, 0, 100)
			e.CurrentAction = string(ActionEating)
		}
	case ActionSeekingRest:
		// 寻找休息处，类似 seeking_food 但恢复 energy
		e.Energy = clamp(e.Energy-0.2, 0, 100)
		if rand.Float64() < 0.15 {
			e.Energy = clamp(e.Energy+25, 0, 100)
			e.CurrentAction = string(ActionSleeping)
		}
	case ActionTalking:
		e.Mood = clamp(e.Mood+0.5, 0, 100)
	case ActionEating:
		e.Hunger = clamp(e.Hunger+20, 0, 100)
	case ActionIdle:
		e.Hunger = clamp(e.Hunger+idleRecovery, 0, 100)
		e.Energy = clamp(e.Energy+idleRecovery*0.5, 0, 100)
		e.Mood = clamp(e.Mood+idleRecovery*0.3, 0, 100)
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
