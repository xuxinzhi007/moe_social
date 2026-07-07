package lifebiz

// 成长阶段常量
const (
	StageJuvenile   = "juvenile"   // 幼年
	StageAdolescent = "adolescent" // 少年
	StageAdult      = "adult"      // 成年
	StageElderly    = "elderly"    // 老年
)

// GrowthStageConfig 成长阶段配置
type GrowthStageConfig struct {
	MaxStatMultiplier float64 // 属性上限修正系数
	DecayMultiplier   float64 // 衰减率修正系数
	ExperienceToNext  float64 // 进入下一阶段所需累计经验（0 表示最终阶段）
}

// GrowthStages 各阶段配置
var GrowthStages = map[string]GrowthStageConfig{
	StageJuvenile:   {MaxStatMultiplier: 0.6, DecayMultiplier: 0.5, ExperienceToNext: 100},
	StageAdolescent: {MaxStatMultiplier: 0.8, DecayMultiplier: 0.8, ExperienceToNext: 300},
	StageAdult:      {MaxStatMultiplier: 1.0, DecayMultiplier: 1.0, ExperienceToNext: 800},
	StageElderly:    {MaxStatMultiplier: 0.8, DecayMultiplier: 1.5, ExperienceToNext: 0},
}

// GrowthOrder 成长阶段顺序
var GrowthOrder = []string{StageJuvenile, StageAdolescent, StageAdult, StageElderly}

// GrowthStageNames 阶段中文名
var GrowthStageNames = map[string]string{
	StageJuvenile:   "幼年",
	StageAdolescent: "少年",
	StageAdult:      "成年",
	StageElderly:    "老年",
}

// GetNextStage 返回下一阶段，如果已是最终阶段返回空字符串
func GetNextStage(current string) string {
	for i, stage := range GrowthOrder {
		if stage == current && i+1 < len(GrowthOrder) {
			return GrowthOrder[i+1]
		}
	}
	return ""
}

// ShouldGrow 检查是否应该成长到下一阶段
func ShouldGrow(currentStage string, experience float64) (string, bool) {
	cfg, ok := GrowthStages[currentStage]
	if !ok {
		return "", false
	}
	if cfg.ExperienceToNext <= 0 {
		// 最终阶段，不再成长
		return "", false
	}
	if experience >= cfg.ExperienceToNext {
		next := GetNextStage(currentStage)
		if next != "" {
			return next, true
		}
	}
	return "", false
}

// ApplyGrowthDecayMultiplier 根据成长阶段调整属性衰减
// 接收原始衰减量，返回修正后的衰减量
func ApplyGrowthDecayMultiplier(stage string, baseDecay float64) float64 {
	cfg, ok := GrowthStages[stage]
	if !ok {
		return baseDecay
	}
	return baseDecay * cfg.DecayMultiplier
}

// GetMaxStat 获取当前阶段的属性上限
func GetMaxStat(stage string) float64 {
	cfg, ok := GrowthStages[stage]
	if !ok {
		return 100
	}
	return 100 * cfg.MaxStatMultiplier
}
