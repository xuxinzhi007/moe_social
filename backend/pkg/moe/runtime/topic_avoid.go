package runtime

import (
	"fmt"
	"strings"

	"backend/pkg/moe/brain"
)

// appendTopicAvoid 把本次试跑内被拒正文的话题摘要追加到避坑块。
func appendTopicAvoid(existing, rejectedContent string) string {
	analysis := brain.AnalyzeTopicsRules(rejectedContent)
	line := fmt.Sprintf("- 勿再写：场景=%s，活动=%s，开头=%s",
		analysis.Scene, analysis.Activity, analysis.OpeningPattern)
	if len(analysis.Themes) > 0 {
		line += "，主题=" + strings.Join(analysis.Themes, "/")
	}
	existing = strings.TrimSpace(existing)
	if existing == "" {
		return "【本次试跑已失败话题 — 必须避开】\n" + line
	}
	if strings.Contains(existing, line) {
		return existing
	}
	return existing + "\n" + line
}
