package brain

import "fmt"

// StabilityGenerationHint 将稳定度写入发帖 prompt，低位时加强约束。
func StabilityGenerationHint(score int) string {
	switch {
	case score >= 65:
		return fmt.Sprintf("【生成稳定度 %d/100】保持口语与主题多样即可。", score)
	case score >= 50:
		return fmt.Sprintf("【生成稳定度 %d/100】近期试跑欠佳：禁止复读「深夜手绘/社区灯光」套路，换具体小事。", score)
	default:
		return fmt.Sprintf("【生成稳定度 %d/100·低位】必须：①只输出合法 JSON ②正文≤120字 ③全新场景 ④禁止抒情排比。", score)
	}
}

// AdjustTemperatureForStability 稳定度越低，采样越保守，减少 0.5B 乱格式。
func AdjustTemperatureForStability(score int, base float64) float64 {
	switch {
	case score < 40:
		if base > 0.72 {
			return 0.72
		}
	case score < 55:
		if base > 0.82 {
			return 0.82
		}
	case score < 65:
		if base > 0.88 {
			return 0.88
		}
	}
	return base
}
