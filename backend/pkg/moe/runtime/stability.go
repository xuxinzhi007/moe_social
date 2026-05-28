package runtime

import (
	"fmt"
	"strings"

	"backend/pkg/moe/brain"
)

// ComputeStabilityDelta 根据本次试跑/发帖结果计算稳定度奖惩。
func ComputeStabilityDelta(ok bool, attempts []GenAttemptRecord, postQuality int) (delta int, feedback string) {
	if ok {
		delta = 6
		if postQuality >= brain.QualityApproveThreshold {
			delta += 4
		} else if postQuality >= 55 {
			delta += 2
		}
		switch len(attempts) {
		case 1:
			delta += 3
		case 2:
			delta += 1
		default:
			if len(attempts) > 2 {
				delta -= len(attempts) - 2
			}
		}
		feedback = fmt.Sprintf("发帖成功 · 正文质量 %d · 生成 %d 次 · 稳定度 %+d", postQuality, len(attempts), delta)
		return delta, feedback
	}

	var parts []string
	for _, a := range attempts {
		switch a.Outcome {
		case GenOutcomeDuplicate:
			delta -= 4
			parts = append(parts, "重复")
		case GenOutcomeTheme:
			delta -= 3
			parts = append(parts, "主题撞车")
		case GenOutcomeLLMError:
			delta -= 6
			parts = append(parts, "LLM失败")
		case GenOutcomeForbidden:
			delta -= 5
			parts = append(parts, "禁标")
		case GenOutcomeNovel:
			delta -= 3
			parts = append(parts, "模板腔")
		case GenOutcomeOK:
			// 不应出现在失败 run
		}
	}
	if len(attempts) >= maxGenerateAttempts {
		delta -= 5
		parts = append(parts, "用尽重试")
	}
	if delta > -2 {
		delta = -2
	}
	reason := strings.Join(parts, "、")
	if reason == "" {
		reason = "生成未通过"
	}
	feedback = fmt.Sprintf("试跑失败 · %s · 共 %d 次 · 稳定度 %+d", reason, len(attempts), delta)
	return delta, feedback
}
