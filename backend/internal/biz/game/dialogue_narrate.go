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
	block              string
	action             string
	npcName            string
	opening            bool
	agentSystemPrompt  string // NPC 绑定 Agent 的 system prompt（可选）
}

func buildDialoguePromptContext(
	scene model.GameScene,
	npcName, persona, gameTime string,
	flags WorldFlags,
	memBlock, historyBlock, loreBlock string,
	action string,
	opening bool,
) dialoguePromptContext {
	return buildDialoguePromptContextWithAgent(
		scene, npcName, persona, gameTime, flags,
		memBlock, historyBlock, loreBlock, action, opening, "",
	)
}

// buildDialoguePromptContextWithAgent NPC-Agent 绑定时，将 Agent 的 system prompt 注入上下文。
func buildDialoguePromptContextWithAgent(
	scene model.GameScene,
	npcName, persona, gameTime string,
	flags WorldFlags,
	memBlock, historyBlock, loreBlock string,
	action string,
	opening bool,
	agentSystemPrompt string,
) dialoguePromptContext {
	if strings.TrimSpace(persona) == "" {
		persona = "镇上的居民，性格随场景而定"
	}
	kind := "续接对话"
	rule := fmt.Sprintf(`2. 玩家刚说：「%s」——必须针对这句话给出全新回应
3. 禁止重复【近期剧情】里已经出现过的台词（尤其禁止再次说「你找我有事」等开场白）
4. 若玩家表示「没什么/没事/算了」，NPC 应自然接话或留有余味，不要重新开场`, action)
	if opening {
		kind = "发起对话"
		rule = fmt.Sprintf(`2. 玩家行动：「%s」——%s 注意到玩家靠近，用符合人设的方式主动搭话（不要用陈词滥调套话）`, action, npcName)
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
	return dialoguePromptContext{block: block, action: action, npcName: npcName, opening: opening, agentSystemPrompt: agentSystemPrompt}
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
	// NPC-Agent 绑定：将 Agent 的 system prompt 注入到对话上下文
	if promptCtx.agentSystemPrompt != "" {
		sys = sys + "\n\n【NPC 背景人设（来自 Agent）】\n" + promptCtx.agentSystemPrompt
	}
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

func lookupNpcTemplate(ctx context.Context, st Store, npcName string) *model.GameNpcTemplate {
	if st == nil {
		return nil
	}
	tpl, err := st.FindNpcTemplateByName(ctx, npcName)
	if err != nil {
		moelog.Infof("game dialogue: lookup npc template %q failed: %v", npcName, err)
		return nil
	}
	return tpl
}

// loadNpcAgentConfig 查找 NPC 模板，若绑定了 Agent 则加载其 system prompt 和 model name。
// 返回空串表示未绑定或加载失败。
func loadNpcAgentConfig(ctx context.Context, st Store, npcName string) (systemPrompt string, modelName string) {
	if st == nil {
		return "", ""
	}
	tpl := lookupNpcTemplate(ctx, st, npcName)
	if tpl == nil || tpl.AgentRuntimeID == nil || *tpl.AgentRuntimeID == 0 {
		return "", ""
	}
	agent, err := st.FindAgentRuntime(ctx, *tpl.AgentRuntimeID)
	if err != nil {
		moelog.Infof("game dialogue: load agent runtime id=%d failed: %v", *tpl.AgentRuntimeID, err)
		return "", ""
	}
	return strings.TrimSpace(agent.SystemPrompt), strings.TrimSpace(agent.ModelName)
}
