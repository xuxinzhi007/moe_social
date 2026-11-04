package replyassistbiz

import (
	"strings"
)

var blockedPhrases = []string{
	"pua",
	"拿捏",
	"欲擒故纵",
	"推拉",
	"服从性测试",
	"打压",
	"冷冻",
	"备胎",
	"舔狗",
	"套路",
	"话术库",
}

func safetyBlockedReason(p llmPayload) (bool, string) {
	blob := strings.ToLower(strings.Join([]string{
		p.Judge.Intent,
		p.Judge.Emotion,
		p.Judge.ReplyStance,
		p.Judge.RiskHint,
	}, " "))
	for _, opt := range p.Options {
		blob += " " + strings.ToLower(opt.Text)
	}
	for _, phrase := range blockedPhrases {
		if strings.Contains(blob, phrase) {
			return true, phrase
		}
	}
	return false, ""
}
