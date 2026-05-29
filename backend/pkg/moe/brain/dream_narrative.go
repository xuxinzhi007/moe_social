package brain

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/pkg/llminference"
)

type dreamNarrativeJSON struct {
	Narrative string `json:"narrative"`
}

// narrateDreamLLM 用本地/配置模型生成入梦叙事（短句，供管理台气泡与 dream log）。
func narrateDreamLLM(
	ctx context.Context,
	inf llminference.Config,
	displayName string,
	facts string,
) (string, error) {
	if !inf.Ready() {
		return "", fmt.Errorf("inference not ready")
	}
	modelName := strings.TrimSpace(inf.DefaultModel)
	if modelName == "" {
		return "", fmt.Errorf("memory_model not configured")
	}
	sys := strings.Join([]string{
		"你是 Moe Bot 的「梦境记录员」。",
		"根据 consolidation 事实写 1～2 句第一人称梦境旁白，口语、温暖、不矫情。",
		"只输出 JSON：{\"narrative\":\"...\"}",
	}, "\n")
	user := fmt.Sprintf("Bot：%s\n事实：%s", displayName, facts)
	raw, err := llminference.Chat(ctx, inf, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{
		Temperature: 0.75,
		TopP:        0.9,
		MaxTokens:   180,
	})
	if err != nil {
		return "", err
	}
	return parseDreamNarrativeJSON(raw)
}

func parseDreamNarrativeJSON(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if m := refineJSONFence.FindStringSubmatch(raw); len(m) > 1 {
		raw = strings.TrimSpace(m[1])
	}
	var out dreamNarrativeJSON
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return strings.TrimSpace(raw), nil
	}
	n := strings.TrimSpace(out.Narrative)
	if n == "" {
		return strings.TrimSpace(raw), nil
	}
	return n, nil
}
