package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"backend/model"
)

// narrateTurn ④ Narrate：元操作（背包/环境/移动）用模板；对话与开放行动调 LLM。
func narrateTurn(
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
	case CmdInspectInventory:
		out := inventoryCheckOutput(snap.Inventory, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "system", nil

	case CmdInspectScene:
		out := environmentCheckOutput(state.Scene, npcViews, snap.SceneItems, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "system", nil

	case CmdExploreWorld:
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "system", nil

	case CmdPickup:
		out := pickupNarrateOutput(cmd.Target, state.PickedItem, state.PickupCreated)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "pickup", nil

	case CmdTravel:
		if state.Moved {
			out := exploreArrivalOutput(state.Scene, npcViews, state.Flags)
			return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "travel", nil
		}
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "system", nil

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
		intent := resolvePlayerIntent(ctx, deps, cmd.Raw, state.Scene.Name, state.Flags)
		memBlock := buildMemoryBlock(ctx, st, snap.UserID, state.NPCs)
		return narrateFreeform(ctx, st, deps, snap, state, cmd.Raw, intent, memBlock, onChunk)

	default:
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "system", nil
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
	// 对话缓存：检查是否命中
	cacheKey := dialogueCacheKey(state.Scene.Name, npcName, action, state.Flags)
	if out, src, ok := globalDialogueCache.get(cacheKey); ok {
		return out, src, nil
	}
	// 优先检查条件对话模板
	if st != nil {
		npcID := findNpcIDByName(state.NPCs, npcName)
		npcFavor := findNpcFavorByName(state.NPCs, snap.Favor, npcName)
		var memTexts []string
		if npcID > 0 {
			memTexts = collectNpcMemoryTexts(ctx, st, snap.UserID, npcID)
		}
		if tpl, favorDelta, matched := findMatchingDialogue(ctx, st, npcName, npcFavor, state.Flags, memTexts); matched {
			prose := strings.NewReplacer(
				"{npc}", npcName,
				"{action}", action,
				"{player}", fmt.Sprintf("%d", snap.UserID),
			).Replace(tpl)
			deltas := map[string]int{}
			if favorDelta != 0 {
				deltas[npcName] = favorDelta
			}
			out := turnLLMOutput{
				Prose:       prose,
				FavorDeltas: deltas,
				SuggestedActions: []string{
					"继续追问",
					fmt.Sprintf("向%s打听钟楼", npcName),
					"结束对话，观察周围",
				},
			}
			// 写入缓存（条件对话可缓存）
			globalDialogueCache.put(cacheKey, out, "dialogue_condition")
			return out, "dialogue_condition", nil
		}
	}

	if snap.LlmOnline && deps.Inference.Ready() {
		memBlock := buildMemoryBlock(ctx, st, snap.UserID, state.NPCs)
		loreBlock := loadLorebookBlock(ctx, st, snap.UserID, state.Scene.Name, action)
		// NPC-Agent 绑定：加载绑定 Agent 的 system prompt 和 model 配置
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
			// LLM 开放对话不缓存
			return out, src, nil
		}
	}
	if opening {
		out := talkStartOutput(ctx, st, npcName)
		out = normalizeTurnOutput(out, state.Flags, state.Scene.Name)
		globalDialogueCache.put(cacheKey, out, "dialogue_fallback")
		return out, "dialogue_fallback", nil
	}
	out := dialogueReplyOutput(ctx, st, npcName, action)
	out = normalizeTurnOutput(out, state.Flags, state.Scene.Name)
	globalDialogueCache.put(cacheKey, out, "dialogue_fallback")
	return out, "dialogue_fallback", nil
}

// --- 结构化叙事模板（Execute 已改状态，此处只写 prose） ---

func talkStartOutput(ctx context.Context, st Store, target string) turnLLMOutput {
	// 尝试从 DB 模板获取开场白
	if tpl := lookupNpcTemplate(ctx, st, target); tpl != nil {
		var fb FallbackResponses
		if err := json.Unmarshal([]byte(tpl.FallbackResponsesJSON), &fb); err == nil && fb.Opening != "" {
			prose := strings.NewReplacer("{target}", target, "{npc}", tpl.DisplayName).
				Replace(fb.Opening)
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
	}
	// 硬编码兜底
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

func dialogueReplyOutput(ctx context.Context, st Store, npcName, action string) turnLLMOutput {
	prose := dialogueTurnProseFromTemplate(ctx, st, npcName, action)
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

// lookupNpcTemplate 按 display_name 查找 NPC 模板，失败时返回 nil 并记录 warn。
func lookupNpcTemplate(ctx context.Context, st Store, npcName string) *model.GameNpcTemplate {
	if st == nil {
		return nil
	}
	tpl, err := st.FindNpcTemplateByName(ctx, npcName)
	if err != nil {
		slog.Warn("[dialogue] 查询 NPC 模板失败，回退硬编码", "npc", npcName, "err", err)
		return nil
	}
	return tpl
}

// dialogueTurnProseFromTemplate 优先使用 DB 模板的 DialogueRulesJSON 匹配玩家输入，
// 未命中则用 FallbackResponsesJSON.Default；任何失败都回退到硬编码 dialogueTurnProse。
func dialogueTurnProseFromTemplate(ctx context.Context, st Store, npcName, action string) string {
	tpl := lookupNpcTemplate(ctx, st, npcName)
	if tpl == nil {
		return dialogueTurnProse(npcName, action)
	}

	a := strings.TrimSpace(action)

	// 尝试解析规则并匹配
	var rules []DialogueRule
	if err := json.Unmarshal([]byte(tpl.DialogueRulesJSON), &rules); err == nil {
		for _, rule := range rules {
			for _, kw := range rule.Keywords {
				if strings.Contains(a, kw) {
					return rule.Response
				}
			}
		}
	}

	// 尝试解析 fallback default
	var fb FallbackResponses
	if err := json.Unmarshal([]byte(tpl.FallbackResponsesJSON), &fb); err == nil && fb.Default != "" {
		return strings.NewReplacer("{action}", a, "{npc}", tpl.DisplayName).
			Replace(fb.Default)
	}

	// 所有解析都失败，回退硬编码
	return dialogueTurnProse(npcName, action)
}

// dialogueTurnProse 硬编码 NPC 对话兜底（DB 不可用或模板解析失败时使用）。
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
	case "酒馆老板":
		switch {
		case strings.Contains(a, "追问") || strings.Contains(a, "继续"):
			return "老板放下杯子，身子微微前倾：「还想打听？先坐下。这镇子的事，不是三两句能说完的。」"
		case strings.Contains(a, "多大") || strings.Contains(a, "几岁"):
			return "老板哼了一声：「问年龄？干我们这行的，年龄写在脸上，也写在酒里。你更该问这镇子最近不太平。」"
		default:
			return fmt.Sprintf("老板看了你一眼：「%s？……行，先坐下说。」", a)
		}
	default:
		if strings.Contains(a, "追问") || strings.Contains(a, "继续") {
			return fmt.Sprintf("%s似乎还有话没说完，等着你的下一个问题。", npcName)
		}
		return fmt.Sprintf("%s回应道：「关于你说的『%s』……让我想想。」", npcName, a)
	}
}

func inventoryCheckOutput(inventory []model.GameWorldItem, flags WorldFlags) turnLLMOutput {
	var prose string
	if len(inventory) == 0 {
		prose = "你解下背包翻找了一遍——里面空空如也，只有风从布缝里钻进来。也许可以在当前场景试试「捡起」或「拿取」什么东西。"
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
	return turnLLMOutput{
		Prose: prose,
		SuggestedActions: []string{
			"观察周围",
			"和附近的人说话",
			"往旅人酒馆方向走",
		},
	}
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
	desc := strings.TrimSpace(scene.Description)
	if desc != "" {
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
			if p := strings.TrimSpace(npc.Persona); p != "" {
				b.WriteString("（")
				b.WriteString(p)
				b.WriteString("）")
			}
		}
		b.WriteString("。\n")
	}
	if len(sceneItems) > 0 {
		b.WriteString("\n你注意到场景中的物品：")
		for i, item := range sceneItems {
			if i > 0 {
				b.WriteString("、")
			}
			b.WriteString(item.Name)
		}
		b.WriteString("。\n")
	}
	b.WriteString(fmt.Sprintf("\n空气里弥漫着%s。", flags.WorldMood))
	return turnLLMOutput{
		Prose: strings.TrimSpace(b.String()),
		SuggestedActions: []string{
			"和老人搭话",
			"前往旅人酒馆",
			"检查背包",
		},
	}
}

func exploreWorldOutput(scene model.GameScene, flags WorldFlags) turnLLMOutput {
	exits := decodeExits(scene.ExitsJSON)
	dirHint := "选一个方向"
	if len(exits) > 0 {
		dirHint = strings.Join(exits, "、")
	}
	prose := fmt.Sprintf(
		`你深吸一口气，准备离开【%s】的舒适圈，向更广阔的世界迈出一步。`+
			`晨雾在你前方分开又合拢，%s 在远处等待着你。`+
			`你可以明确说出一个方向或目的地，例如「往东走」或「进入旅人酒馆」。`,
		scene.Name, dirHint,
	)
	_ = flags
	return turnLLMOutput{
		Prose: prose,
		SuggestedActions: []string{
			"前往旅人酒馆",
			"走向广场上的老人",
			"观察钟楼",
		},
	}
}

func npcPresent(name string, npcs []NpcView) bool {
	name = strings.TrimSpace(name)
	if name == "" {
		return false
	}
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
