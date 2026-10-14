package lifebiz

// PersonalityWeights 性格对应的行为偏好阈值。
// 仅调整 decideAction 系列里已有的阈值，不引入新行为类型。
type PersonalityWeights struct {
	WalkChance         float64 // 随机走动概率。
	SleepEnergyBelow   float64 // 低于该能量进入睡眠。
	WanderMoodBelow    float64 // 低于该情绪进入漫游。
	SocialApproachDist float64 // 主动走向朋友的距离上限。
}

const (
	PersonalityDiligent = "diligent"
	PersonalityCurious  = "curious"
	PersonalitySocial   = "social"
	PersonalitySleepy   = "sleepy"
)

// personalityDefaults 与 behavior.go 历史硬编码阈值一致，空性格行为保持不变。
var personalityDefaults = PersonalityWeights{
	WalkChance:         0.18,
	SleepEnergyBelow:   15,
	WanderMoodBelow:    28,
	SocialApproachDist: 200,
}

var personalityTable = map[string]PersonalityWeights{
	PersonalityDiligent: {WalkChance: 0.32, SleepEnergyBelow: 12, WanderMoodBelow: 28, SocialApproachDist: 200},
	PersonalityCurious:  {WalkChance: 0.24, SleepEnergyBelow: 15, WanderMoodBelow: 36, SocialApproachDist: 220},
	PersonalitySocial:   {WalkChance: 0.18, SleepEnergyBelow: 15, WanderMoodBelow: 28, SocialApproachDist: 280},
	PersonalitySleepy:   {WalkChance: 0.10, SleepEnergyBelow: 24, WanderMoodBelow: 24, SocialApproachDist: 160},
}

// weightsFor 查性格偏好表，未知或空性格回落到默认值。
func weightsFor(personality string) PersonalityWeights {
	if w, ok := personalityTable[personality]; ok {
		return w
	}
	return personalityDefaults
}
