package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/llminference"
)

type smartDecisionJSON struct {
	ShouldPost bool   `json:"should_post"`
	Reason     string `json:"reason"`
}

// evaluateSmartPost 由 LLM 判断是否适合此刻发帖（智能发送 v1）。
func evaluateSmartPost(ctx context.Context, deps Deps, rt model.MoeAgentRuntime, opts SmartOpts) (bool, string, error) {
	if !deps.Inference.Ready() {
		return false, "", fmt.Errorf("未配置 llm_inference，智能发送不可用")
	}
	if rt.PostQuotaDaily > 0 && rt.PostsToday >= rt.PostQuotaDaily {
		return false, "已达今日发帖配额", nil
	}
	minGap := time.Duration(opts.MinIntervalHours) * time.Hour
	if minGap <= 0 {
		minGap = 2 * time.Hour
	}
	if rt.LastRunAt != nil && time.Since(*rt.LastRunAt) < minGap {
		return false, fmt.Sprintf("距上次执行不足 %v", minGap), nil
	}

	ctxBlock := gatherPostContext(ctx, deps, rt)
	modelName := resolvePostModel(deps, rt)

	sys := strings.Join([]string{
		"你是社区 Bot 调度助手，负责判断「现在是否适合发一条新动态」。",
		"考虑：社区是否冷清/过热、Bot 今日已发数量、记忆与近期动态是否值得发声。",
		"保守原则：没有好话题时不要硬发。",
		"只输出 JSON：{\"should_post\":true/false,\"reason\":\"简短中文理由\"}",
	}, "\n")

	quotaNote := "无限制"
	if rt.PostQuotaDaily > 0 {
		quotaNote = fmt.Sprintf("%d/%d", rt.PostsToday, rt.PostQuotaDaily)
	}
	lastNote := "从未"
	if rt.LastRunAt != nil {
		lastNote = rt.LastRunAt.Format(time.RFC3339)
	}

	user := fmt.Sprintf(`Bot: %s (%s)
今日发帖: %s
上次执行: %s

【社区脉搏】
%s

【Bot 记忆】
%s

现在是否发帖？`, displayName(rt), rt.AgentKey, quotaNote, lastNote, ctxBlock.posts, ctxBlock.memories)

	raw, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{
		Temperature: 0.3,
		MaxTokens:   256,
	})
	if err != nil {
		return false, "", fmt.Errorf("智能决策 LLM 失败: %w", err)
	}

	dec, err := parseSmartDecision(raw)
	if err != nil {
		return false, "", err
	}
	return dec.ShouldPost, strings.TrimSpace(dec.Reason), nil
}

func parseSmartDecision(raw string) (smartDecisionJSON, error) {
	raw = strings.TrimSpace(raw)
	if m := jsonFenceRe.FindStringSubmatch(raw); len(m) > 1 {
		raw = strings.TrimSpace(m[1])
	}
	var out smartDecisionJSON
	if err := json.Unmarshal([]byte(raw), &out); err == nil {
		return out, nil
	}
	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start >= 0 && end > start {
		if err := json.Unmarshal([]byte(raw[start:end+1]), &out); err == nil {
			return out, nil
		}
	}
	return smartDecisionJSON{}, fmt.Errorf("无法解析智能决策 JSON")
}

// smartRetryAt 本次跳过后的下次评估时间。
func smartRetryAt(now time.Time, opts SmartOpts) time.Time {
	mins := opts.RetryIntervalMinutes
	if mins <= 0 {
		mins = 30
	}
	return now.Add(time.Duration(mins) * time.Minute)
}
