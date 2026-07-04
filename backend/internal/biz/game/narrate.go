package gamebiz

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"backend/model"
)

// narrateTurn ④ Narrate：在线走 World Agent；离线走规则兜底。
func narrateTurn(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	cmd Command,
	state TurnState,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if cmd.Kind == CmdAgent {
		if snap.LlmOnline && deps.Inference.Ready() {
			if IsAgentMode(deps) {
				return runAgentTurn(ctx, st, deps, snap, &state, cmd.Raw, onChunk)
			}
			// narrator 模式：Go 管世界，小模型只写叙事
			offCmd := parseOfflineCommand(cmd.Raw, snap)
			return narrateTurnOffline(ctx, st, deps, snap, offCmd, state, onChunk)
		}
		offCmd := parseOfflineCommand(cmd.Raw, snap)
		return narrateTurnOffline(ctx, st, deps, snap, offCmd, state, onChunk)
	}
	return narrateTurnOffline(ctx, st, deps, snap, cmd, state, onChunk)
}

func narrateTurnOffline(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	cmd Command,
	state TurnState,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	favor := snap.Favor
	npcViews := npcViewsFromModels(state.NPCs, favor)

	switch cmd.Kind {
	case CmdTalkStart:
		target := cmd.Target
		if target == "" {
			target = pickTalkTarget(npcViews, state.Scene.Name)
		}
		return narrateDialogue(ctx, st, deps, snap, state, target, cmd.Raw, true, onChunk)

	case CmdTalkReply:
		npcName := cmd.Target
		if npcName == "" {
			npcName = strings.TrimSpace(state.Flags.LastTalkNPC)
		}
		if !npcPresent(npcName, npcViews) {
			npcName = pickTalkTarget(npcViews, state.Scene.Name)
		}
		return narrateDialogue(ctx, st, deps, snap, state, npcName, cmd.Raw, false, onChunk)

	case CmdFreeform:
		return narrateActionLLM(ctx, st, deps, snap, cmd, state, onChunk)

	default:
		if snap.LlmOnline && deps.Inference.Ready() {
			if IsNarratorMode(deps) && isNarratorDeterministicKind(cmd.Kind) {
				return narrateOfflineFallback(cmd, snap, state, npcViews)
			}
			return narrateActionLLM(ctx, st, deps, snap, cmd, state, onChunk)
		}
		slog.Warn("[narrate] LLM 离线，使用兜底模板", "kind", cmd.Kind, "action", cmd.Raw)
		return narrateOfflineFallback(cmd, snap, state, npcViews)
	}
}

func narrateFreeform(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	state TurnState,
	action string,
	intent PlayerIntent,
	memBlock string,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	npcViews := npcViewsFromModels(state.NPCs, snap.Favor)
	dialogueBlock := buildDialogueContextBlock(state.Flags)
	loreBlock := loadLorebookBlock(ctx, st, snap.UserID, state.Scene.Name, action)
	arcBlock := storyArcBlock(state.Flags)
	promptCtx := buildActPromptContext(
		state.Scene, npcViews, snap.Session.GameTime, state.Flags,
		memBlock, intent, snap.Inventory, snap.SceneItems, action,
		loreBlock, arcBlock, snap.HistoryBlock, dialogueBlock,
	)
	if isMetaQuestion(action) {
		promptCtx.sceneBlock = "【特殊指令】玩家在询问 AI/模型/身份。请用 2-3 句打破第四面墙直接回答，然后自然回到【" +
			state.Scene.Name + "】的世界叙事，不要重复场景介绍原文。\n\n" + promptCtx.sceneBlock
	}
	if onChunk != nil {
		out, src, err := resolveTurnOutputStream(ctx, deps, promptCtx, action, state.Scene, npcViews, state.Flags, intent, onChunk)
		return out, src, err
	}
	out, src := resolveTurnOutput(ctx, deps, promptCtx, action, state.Scene, npcViews, state.Flags, intent)
	return out, src, nil
}

func narrateDialogue(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	state TurnState,
	npcName, action string,
	opening bool,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if snap.LlmOnline && deps.Inference.Ready() {
		memBlock := buildMemoryBlock(ctx, st, snap.UserID, state.NPCs)
		loreBlock := loadLorebookBlock(ctx, st, snap.UserID, state.Scene.Name, action)
		agentPrompt, agentModel := loadNpcAgentConfig(ctx, st, npcName)
		if agentModel != "" {
			deps.Model = agentModel
		}
		promptCtx := buildDialoguePromptContextWithAgent(
			state.Scene, npcName, npcPersona(npcName, state.NPCs),
			snap.Session.GameTime, state.Flags,
			memBlock, snap.HistoryBlock, loreBlock, action, opening,
			agentPrompt,
		)
		if out, src, err := resolveDialogueLLM(ctx, deps, promptCtx, state.Flags, state.Scene.Name, onChunk); err == nil {
			return out, src, nil
		}
	}
	slog.Warn("[dialogue] LLM 不可用，使用离线兜底", "npc", npcName, "action", action)
	if opening {
		out := talkStartOutput(npcName)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	}
	out := dialogueReplyOutput(npcName, action)
	return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
}

// --- 离线兜底（AI 不可用时） ---

func talkStartOutput(target string) turnLLMOutput {
	prose := fmt.Sprintf(
		`你走向%s，对方从手头的事里抬起头。空气里有一瞬的停顿，随后%s开口了：「……你找我有事？」`,
		target, target,
	)
	return turnLLMOutput{
		Prose:       prose,
		FavorDeltas: map[string]int{target: 1},
		SuggestedActions: []string{
			fmt.Sprintf("问%s这里的情况", target),
			"继续追问",
			"观察周围",
		},
	}
}

func dialogueReplyOutput(npcName, action string) turnLLMOutput {
	prose := dialogueTurnProse(npcName, action)
	return turnLLMOutput{
		Prose:       prose,
		FavorDeltas: map[string]int{npcName: 1},
		SuggestedActions: []string{
			"继续追问",
			fmt.Sprintf("向%s打听钟楼", npcName),
			"结束对话，观察周围",
		},
	}
}

func dialogueTurnProse(npcName, action string) string {
	a := strings.TrimSpace(action)
	switch npcName {
	case "老人":
		switch {
		case strings.Contains(a, "追问") || strings.Contains(a, "继续"):
			return "老人把烟斗在指间转了一圈，目光再次落在你身上：「你想知道什么？钟的事，还是雾的事？问吧。」"
		case strings.Contains(a, "多大") || strings.Contains(a, "几岁") || strings.Contains(a, "年龄"):
			return "老人愣了一下，随即笑出声来，笑声在晨雾里有些发闷：「老了……七十三啦。这镇子的事，我比钟楼还清楚。」"
		case strings.Contains(a, "没有") || strings.Contains(a, "不"):
			return "老人把烟斗在膝上轻敲两下：「没有？……那你站在这里，是在等雾散，还是在等钟响？」"
		case strings.Contains(a, "钟"):
			return "老人眼神一暗，声音几乎只剩气音：「那座钟……午夜会响十三下。多出来的那一响，是给谁听的，从来没人说清。」"
		default:
			return fmt.Sprintf("老人听着你说「%s」，沉默片刻后缓缓开口：「……嗯。还有什么想问的？」", a)
		}
	default:
		return fmt.Sprintf("%s回应道：「关于你说的『%s』……让我想想。」", npcName, a)
	}
}

func inventoryCheckOutput(inventory []model.GameWorldItem, flags WorldFlags) turnLLMOutput {
	var prose string
	if len(inventory) == 0 {
		prose = "你解下背包翻找了一遍——里面空空如也，只有风从布缝里钻进来。"
	} else {
		var b strings.Builder
		b.WriteString("你打开背包，逐一清点：\n")
		for i, item := range inventory {
			name := strings.TrimSpace(item.Name)
			if name == "" {
				continue
			}
			desc := strings.TrimSpace(item.Description)
			if desc != "" {
				b.WriteString(fmt.Sprintf("%d. %s — %s\n", i+1, name, desc))
			} else {
				b.WriteString(fmt.Sprintf("%d. %s\n", i+1, name))
			}
		}
		prose = strings.TrimSpace(b.String())
	}
	_ = flags
	return turnLLMOutput{Prose: prose}
}

func environmentCheckOutput(
	scene model.GameScene,
	npcs []NpcView,
	sceneItems []model.GameWorldItem,
	flags WorldFlags,
) turnLLMOutput {
	exits := decodeExits(scene.ExitsJSON)
	var b strings.Builder
	b.WriteString(fmt.Sprintf("你停下来，仔细感知【%s】的环境。\n\n", scene.Name))
	if desc := strings.TrimSpace(scene.Description); desc != "" {
		b.WriteString(desc)
		b.WriteString("\n\n")
	}
	if len(exits) > 0 {
		b.WriteString("可见去向：")
		b.WriteString(strings.Join(exits, "、"))
		b.WriteString("。\n")
	}
	if len(npcs) > 0 {
		b.WriteString("\n在场的人：")
		for i, npc := range npcs {
			if i > 0 {
				b.WriteString("；")
			}
			b.WriteString(npc.Name)
		}
		b.WriteString("。\n")
	}
	_ = sceneItems
	b.WriteString(fmt.Sprintf("\n空气里弥漫着%s。", flags.WorldMood))
	return turnLLMOutput{Prose: strings.TrimSpace(b.String())}
}

func exploreWorldOutput(scene model.GameScene, flags WorldFlags) turnLLMOutput {
	exits := decodeExits(scene.ExitsJSON)
	dirHint := "远方"
	if len(exits) > 0 {
		dirHint = strings.Join(exits, "、")
	}
	prose := fmt.Sprintf(`你深吸一口气，准备离开【%s】，向%s迈出一步。`, scene.Name, dirHint)
	_ = flags
	return turnLLMOutput{Prose: prose}
}

func npcPresent(name string, npcs []NpcView) bool {
	name = strings.TrimSpace(name)
	for _, npc := range npcs {
		if npc.Name == name {
			return true
		}
	}
	return name == "酒馆老板" || name == "老人" || name == "乞丐"
}

func utf8RuneCount(s string) int {
	return len([]rune(s))
}

func isMetaQuestion(action string) bool {
	lower := strings.ToLower(strings.TrimSpace(action))
	for _, k := range []string{
		"什么模型", "哪个模型", "你是ai", "你是 ai", "你是人工智能",
		"gpt", "claude", "llama", "qwen", "你是谁", "你是什么",
	} {
		if strings.Contains(lower, k) {
			return true
		}
	}
	return strings.Contains(action, "模型") && (strings.Contains(action, "什么") || strings.Contains(action, "哪"))
}
