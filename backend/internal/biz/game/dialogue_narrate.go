package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/internal/platform/moelog"
	"backend/model"
	"backend/pkg/llminference"
)

// dialoguePromptContext NPC 对话专用 prompt（比开放世界 prompt 更短、更聚焦）。
type dialoguePromptContext struct {
	block   string
	action  string
	npcName string
	opening bool
}

func buildDialoguePromptContext(
	scene model.GameScene,
	npcName, persona, gameTime string,
	flags WorldFlags,
	memBlock, historyBlock, loreBlock string,
	action string,
	opening bool,
) dialoguePromptContext {
	if strings.TrimSpace(persona) == "" {
		persona = "镇上的居民，性格随场景而定"
	}
	kind := "续接对话"
	rule := fmt.Sprintf("2. 玩家刚说：「%s」——你必须针对这句话回应，禁止空泛套话（如「还有什么想问的」）", action)
	if opening {
		kind = "发起对话"
		rule = fmt.Sprintf("2. 玩家行动：「%s」——%s 注意到玩家靠近，主动开口搭话", action, npcName)
	}
	block := fmt.Sprintf(`【场景】%s
%s
【时间】%s
【对话对象】%s
【人设】%s
%s%s%s
【任务】%s
【规则】
1. 你正在写文字冒险游戏里 NPC「%s」的回应段落
%s
3. 输出 80-200 字中文小说段落，必须包含 %s 的台词（引号内），可夹少量动作/神态
4. 必须承接【近期对话】，保持人物性格与世界观一致
5. 禁止重复场景描述原文，禁止 JSON/markdown`,
		scene.Name,
		strings.TrimSpace(scene.Description),
		gameTime,
		npcName,
		persona,
		historyBlock,
		memBlock,
		loreBlock,
		kind,
		npcName,
		rule,
		npcName,
	)
	return dialoguePromptContext{block: block, action: action, npcName: npcName, opening: opening}
}

func buildDialoguePromptUser(ctx dialoguePromptContext) string {
	if ctx.opening {
		return fmt.Sprintf("%s\n\n请写出 %s 主动与玩家搭话的开场：", ctx.block, ctx.npcName)
	}
	return fmt.Sprintf("%s\n\n请写出 %s 对玩家的回应：", ctx.block, ctx.npcName)
}

func resolveDialogueLLM(
	ctx context.Context,
	deps TurnDeps,
	promptCtx dialoguePromptContext,
	flags WorldFlags,
	sceneName string,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if !deps.Inference.Ready() {
		return turnLLMOutput{}, "dialogue_fallback", fmt.Errorf("inference offline")
	}
	candidates := turnModelCandidates(ctx, deps)
	var lastErr error
	for _, modelName := range candidates {
		tryDeps := deps
		tryDeps.Model = modelName
		out, err := callDialogueLLM(ctx, tryDeps, promptCtx, onChunk)
		if err != nil {
			lastErr = err
			continue
		}
		out = normalizeTurnOutput(out, flags, sceneName)
		if isValidProse(out.Prose) {
			out.FavorDeltas = map[string]int{promptCtx.npcName: 1}
			if len(out.SuggestedActions) == 0 {
				out.SuggestedActions = dialogueSuggestedActions(promptCtx.npcName)
			}
			return out, "dialogue_llm", nil
		}
	}
	if lastErr != nil {
		moelog.Infof("game dialogue fallback: llm failed npc=%q action=%q err=%v",
			promptCtx.npcName, promptCtx.action, lastErr)
	}
	return turnLLMOutput{}, "dialogue_fallback", fmt.Errorf("dialogue llm empty")
}

func callDialogueLLM(
	ctx context.Context,
	deps TurnDeps,
	promptCtx dialoguePromptContext,
	onChunk ProseStreamHandler,
) (turnLLMOutput, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	sys := fmt.Sprintf("你是文字冒险游戏中 NPC「%s」的对话写手。只输出一段中文叙事正文，含该 NPC 的台词。", promptCtx.npcName)
	user := buildDialoguePromptUser(promptCtx)
	opts := llminference.ChatOptions{Temperature: 0.92, MaxTokens: 400}

	var content string
	var err error
	if onChunk != nil {
		handler := llminference.StreamHandler(onChunk)
		content, err = llminference.ChatStream(ctx, deps.Inference, modelName, []llminference.Message{
			{Role: "system", Content: sys},
			{Role: "user", Content: user},
		}, opts, handler)
	} else {
		content, err = llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
			{Role: "system", Content: sys},
			{Role: "user", Content: user},
		}, opts)
	}
	if err != nil {
		return turnLLMOutput{}, err
	}
	content = strings.TrimSpace(content)
	if content == "" {
		return turnLLMOutput{}, fmt.Errorf("empty dialogue response")
	}
	if out, ok := parseTurnLLMContent(content); ok && isValidProse(out.Prose) {
		return out, nil
	}
	return turnLLMOutput{Prose: content}, nil
}

func dialogueSuggestedActions(npcName string) []string {
	return []string{
		"继续追问",
		fmt.Sprintf("向%s打听钟楼", npcName),
		"结束对话，观察周围",
	}
}

func npcPersona(name string, npcs []model.GameNpc) string {
	name = strings.TrimSpace(name)
	for _, npc := range npcs {
		if npc.Name == name {
			return strings.TrimSpace(npc.Persona)
		}
	}
	return ""
}
