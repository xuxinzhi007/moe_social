package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/pkg/llminference"
)

func callAgentLLMRaw(ctx context.Context, deps TurnDeps, modelName, prompt string) (string, error) {
	content, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "你是开放世界游戏 Agent。只输出合法 JSON，prose 必须是中文叙事正文。"},
		{Role: "user", Content: prompt},
	}, llminference.ChatOptions{Temperature: 0.75, MaxTokens: 480})
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(content), nil
}

// streamAgentProse 工具阶段完成后单独流式写叙事（JSON 步失败时的快速路径）。
func streamAgentProse(
	ctx context.Context,
	deps TurnDeps,
	snap *SessionSnapshot,
	state TurnState,
	action string,
	toolNotes []string,
	onChunk ProseStreamHandler,
) (string, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	var notesBlock string
	if len(toolNotes) > 0 {
		notesBlock = strings.Join(toolNotes, "\n") + "\n"
	}
	prompt := fmt.Sprintf(`你是「迷雾小镇」叙事作者。根据【世界事实】写 150-220 字中文小说正文，承接【近期剧情】，含 NPC 台词。
禁止 JSON、禁止列表、禁止复读场景原文、禁止输出任何指令说明。

%s
【位置】%s
【玩家行动】%s
%s
直接输出叙事正文：`,
		snap.HistoryBlock,
		state.Scene.Name,
		action,
		notesBlock,
	)
	return llminference.ChatStream(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "只输出中文小说正文，不要 JSON。"},
		{Role: "user", Content: prompt},
	}, llminference.ChatOptions{Temperature: 0.88, MaxTokens: 700}, func(chunk string) error {
		if onChunk == nil || chunk == "" {
			return nil
		}
		return onChunk(chunk)
	})
}
