package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/model"
)

// buildExecutionBrief 本回合已落库的状态事实（供 LLM 叙事，不是文案模板）。
func buildExecutionBrief(cmd Command, state TurnState, snap *SessionSnapshot) string {
	var b strings.Builder
	switch cmd.Kind {
	case CmdTravel:
		if state.Moved {
			fmt.Fprintf(&b, "- 玩家已抵达【%s】\n", state.Scene.Name)
			if d := strings.TrimSpace(state.Scene.Description); d != "" {
				fmt.Fprintf(&b, "- 新场景描述：%s\n", d)
			}
			if len(state.NPCs) > 0 {
				fmt.Fprintf(&b, "- 在场 NPC：%s\n", joinNpcNames(state.NPCs))
			}
		} else {
			b.WriteString("- 玩家试图移动但未进入新区域（方向不明确或路径受阻）\n")
		}
	case CmdPickup:
		name := normalizePickupItemName(cmd.Target)
		if name == "" {
			b.WriteString("- 玩家试图拾取物品但未指明是什么\n")
		} else if state.PickedItem.Name != "" && state.PickedItem.InInventory {
			if state.PickupCreated {
				fmt.Fprintf(&b, "- 玩家刚刚拾取并收入背包：%s\n", name)
			} else {
				fmt.Fprintf(&b, "- 玩家从场景拾取并收入背包：%s\n", name)
			}
			if d := strings.TrimSpace(state.PickedItem.Description); d != "" {
				fmt.Fprintf(&b, "- 物品说明：%s\n", d)
			}
		} else if state.PickedItem.Name != "" && !state.PickedItem.IsTakeable {
			fmt.Fprintf(&b, "- 玩家无法拿取：%s（固定于场景）\n", name)
		}
	case CmdInspectInventory:
		b.WriteString("- 玩家正在查看背包内容\n")
		appendInventoryFacts(&b, snap.Inventory)
	case CmdInspectScene:
		fmt.Fprintf(&b, "- 玩家正在观察【%s】的环境\n", state.Scene.Name)
		appendSceneFacts(&b, state.Scene, snap.SceneItems, state.NPCs)
	case CmdExploreWorld:
		fmt.Fprintf(&b, "- 玩家准备离开【%s】向更广阔区域探索\n", state.Scene.Name)
		exits := decodeExits(state.Scene.ExitsJSON)
		if len(exits) > 0 {
			fmt.Fprintf(&b, "- 可见去向：%s\n", strings.Join(exits, "、"))
		}
	case CmdTalkStart, CmdTalkReply:
		npc := strings.TrimSpace(cmd.Target)
		if npc == "" {
			npc = strings.TrimSpace(state.Flags.LastTalkNPC)
		}
		if npc != "" {
			fmt.Fprintf(&b, "- 正在与【%s】对话\n", npc)
		}
		fmt.Fprintf(&b, "- 玩家说：%s\n", strings.TrimSpace(cmd.Raw))
	case CmdFreeform:
		fmt.Fprintf(&b, "- 玩家自由行动：%s\n", strings.TrimSpace(cmd.Raw))
		b.WriteString("- 注意：若行动不可能，叙事应明确受阻，不要假装成功\n")
	default:
		if strings.TrimSpace(cmd.Raw) != "" {
			fmt.Fprintf(&b, "- 玩家行动：%s\n", strings.TrimSpace(cmd.Raw))
		}
		appendSceneFacts(&b, state.Scene, snap.SceneItems, state.NPCs)
	}
	return strings.TrimSpace(b.String())
}

func appendInventoryFacts(b *strings.Builder, items []model.GameWorldItem) {
	if len(items) == 0 {
		b.WriteString("- 背包当前为空\n")
		return
	}
	b.WriteString("- 背包物品：\n")
	for _, item := range items {
		name := strings.TrimSpace(item.Name)
		if name == "" {
			continue
		}
		desc := strings.TrimSpace(item.Description)
		if desc != "" {
			fmt.Fprintf(b, "  · %s（%s）\n", name, desc)
		} else {
			fmt.Fprintf(b, "  · %s\n", name)
		}
	}
}

func appendSceneFacts(b *strings.Builder, scene model.GameScene, sceneItems []model.GameWorldItem, npcs []model.GameNpc) {
	if d := strings.TrimSpace(scene.Description); d != "" {
		fmt.Fprintf(b, "- 场景：%s\n", d)
	}
	exits := decodeExits(scene.ExitsJSON)
	if len(exits) > 0 {
		fmt.Fprintf(b, "- 出口：%s\n", strings.Join(exits, "、"))
	}
	if len(npcs) > 0 {
		b.WriteString("- 在场人物：\n")
		for _, npc := range npcs {
			fmt.Fprintf(b, "  · %s：%s\n", npc.Name, strings.TrimSpace(npc.Persona))
		}
	}
	if len(sceneItems) > 0 {
		b.WriteString("- 可见物品：")
		for i, item := range sceneItems {
			if i > 0 {
				b.WriteString("、")
			}
			b.WriteString(item.Name)
		}
		b.WriteString("\n")
	}
}

func joinNpcNames(npcs []model.GameNpc) string {
	names := make([]string, 0, len(npcs))
	for _, n := range npcs {
		if n.Name != "" {
			names = append(names, n.Name)
		}
	}
	return strings.Join(names, "、")
}

func intentForCommand(cmd Command) PlayerIntent {
	switch cmd.Kind {
	case CmdInspectInventory:
		return PlayerIntent{Type: "inventory", Summary: cmd.Raw}
	case CmdInspectScene:
		return PlayerIntent{Type: "observe", Summary: cmd.Raw}
	case CmdTravel:
		return PlayerIntent{Type: "travel", Summary: cmd.Raw, Target: cmd.Target}
	case CmdPickup:
		return PlayerIntent{Type: "pickup", Summary: cmd.Raw, Target: cmd.Target}
	case CmdExploreWorld:
		return PlayerIntent{Type: "travel", Summary: cmd.Raw}
	default:
		return PlayerIntent{Type: "interact", Summary: cmd.Raw}
	}
}

// narrateActionLLM 结构化行动：Execute 已改 DB，LLM 只负责开放世界叙事。
func narrateActionLLM(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	cmd Command,
	state TurnState,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if IsNarratorMode(deps) {
		if out, src, ok := tryNarratorRuleOutput(cmd, state.Scene); ok {
			return normalizeTurnOutput(out, state.Flags, state.Scene.Name), src, nil
		}
	}
	intent := intentForCommand(cmd)
	npcViews := npcViewsFromModels(state.NPCs, snap.Favor)
	brief := buildExecutionBrief(cmd, state, snap)

	var promptCtx actPromptContext
	if IsNarratorMode(deps) {
		promptCtx = actPromptContext{
			sceneBlock: buildNarratorSceneBlock(state.Scene, brief, npcViews, snap.Session.GameTime),
			action:     cmd.Raw,
		}
	} else {
		memBlock := buildMemoryBlock(ctx, st, snap.UserID, state.NPCs)
		dialogueBlock := buildDialogueContextBlock(state.Flags)
		loreBlock := loadLorebookBlock(ctx, st, snap.UserID, state.Scene.Name, cmd.Raw)
		arcBlock := storyArcBlock(state.Flags)
		promptCtx = buildActPromptContext(
			state.Scene, npcViews, snap.Session.GameTime, state.Flags,
			memBlock, intent, snap.Inventory, snap.SceneItems, cmd.Raw,
			loreBlock, arcBlock, snap.HistoryBlock, dialogueBlock,
		)
		if brief != "" {
			promptCtx.sceneBlock = fmt.Sprintf("【玩家原话】%s\n\n【本回合状态变更（叙事必须体现，禁止与事实矛盾；禁止列表式报幕）】\n%s\n\n%s",
				cmd.Raw, brief, promptCtx.sceneBlock)
		} else {
			promptCtx.sceneBlock = fmt.Sprintf("【玩家原话】%s\n\n%s", cmd.Raw, promptCtx.sceneBlock)
		}
	}

	if onChunk != nil {
		out, src, err := resolveTurnOutputStream(ctx, deps, promptCtx, cmd.Raw, state.Scene, npcViews, state.Flags, intent, onChunk)
		if err != nil {
			return out, src, err
		}
		return out, "llm_action", nil
	}
	out, src := resolveTurnOutput(ctx, deps, promptCtx, cmd.Raw, state.Scene, npcViews, state.Flags, intent)
	if src == "fallback" {
		return out, "llm_action_fallback", nil
	}
	return out, "llm_action", nil
}

// narrateOfflineFallback LLM 离线时的最小兜底（不应在 AI 在线时出现）。
func narrateOfflineFallback(
	cmd Command,
	snap *SessionSnapshot,
	state TurnState,
	npcViews []NpcView,
) (turnLLMOutput, string, error) {
	switch cmd.Kind {
	case CmdInspectInventory:
		out := inventoryCheckOutput(snap.Inventory, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	case CmdInspectScene:
		out := environmentCheckOutput(state.Scene, npcViews, snap.SceneItems, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	case CmdExploreWorld:
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	case CmdPickup:
		out := pickupNarrateOutput(cmd.Target, state.PickedItem, state.PickupCreated)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	case CmdTravel:
		if state.Moved {
			out := exploreArrivalOutput(state.Scene, npcViews, state.Flags)
			return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
		}
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	default:
		out := exploreWorldOutput(state.Scene, state.Flags)
		return normalizeTurnOutput(out, state.Flags, state.Scene.Name), "offline_fallback", nil
	}
}
