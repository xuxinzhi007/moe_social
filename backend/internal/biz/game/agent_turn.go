package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

const agentMaxSteps = 2 // 预加载上下文后：工具步 + 叙事步，避免 4 轮串行 LLM

func runAgentTurn(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	state *TurnState,
	action string,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if !deps.Inference.Ready() {
		return turnLLMOutput{}, "offline", fmt.Errorf("inference offline")
	}
	wctx := &worldToolContext{
		ctx: ctx, st: st, deps: deps, userID: snap.UserID, snap: snap, state: state,
	}
	// 服务端预加载世界上下文，省掉模型第一轮 world_get_context 往返（~15-20s）
	if ctxNote, err := wctx.toolGetContext(); err == nil && ctxNote != "" {
		wctx.notes = append(wctx.notes, "【当前世界快照】\n"+ctxNote)
	}

	var lastOut agentTurnOutput
	toolsRan := false
	for step := 0; step < agentMaxSteps; step++ {
		prompt := buildAgentPrompt(wctx.ctx, wctx.st, snap, *wctx.state, action, wctx.notes, step)
		raw, err := callAgentLLM(ctx, deps, prompt)
		if err != nil {
			return turnLLMOutput{}, "agent_error", err
		}
		var out agentTurnOutput
		if json.Unmarshal([]byte(raw), &out) != nil {
			if prose, ok := acceptAgentProse(stripJSONFence(raw)); ok {
				return finalizeAgentOutput(prose, nil, state.Flags, onChunk)
			}
			break
		}
		lastOut = out
		if len(out.ToolCalls) > 0 {
			toolsRan = true
			for _, tc := range out.ToolCalls {
				// 上下文已预加载，跳过重复的 get_context
				if tc.Name == "world_get_context" && step == 0 && len(wctx.notes) > 0 {
					continue
				}
				note, err := executeWorldTool(wctx, tc)
				if err != nil {
					wctx.notes = append(wctx.notes, fmt.Sprintf("工具 %s 失败：%v", tc.Name, err))
				} else if note != "" {
					wctx.notes = append(wctx.notes, note)
				}
			}
		}
		prose, ok := acceptAgentProse(out.Prose)
		if ok && len(out.ToolCalls) == 0 {
			return finalizeAgentOutput(prose, out.SuggestedActions, state.Flags, onChunk)
		}
		if ok && toolsRan {
			return finalizeAgentOutput(prose, out.SuggestedActions, state.Flags, onChunk)
		}
	}

	if p, ok := acceptAgentProse(lastOut.Prose); ok {
		return finalizeAgentOutput(p, lastOut.SuggestedActions, state.Flags, onChunk)
	}

	// 工具已执行但 JSON prose 无效：流式生成叙事（用户不必等整段 JSON 回合结束）
	prose, err := streamAgentProse(ctx, deps, snap, *wctx.state, action, wctx.notes, onChunk)
	if err == nil {
		if p, ok := acceptAgentProse(prose); ok {
			return turnLLMOutput{
				Prose:            p,
				SuggestedActions: defaultAgentSuggestedActions(state.Flags),
				FavorDeltas:      lastOut.FavorDeltas,
			}, "agent_prose_stream", nil
		}
	}

	fallback := synthesizeAgentProse(action, state.Scene.Name, wctx.notes, state.Flags)
	if onChunk != nil {
		_ = onChunk(fallback)
	}
	return turnLLMOutput{
		Prose:            fallback,
		SuggestedActions: defaultAgentSuggestedActions(state.Flags),
		FavorDeltas:      lastOut.FavorDeltas,
	}, "agent_synthesized", nil
}

func finalizeAgentOutput(prose string, actions []string, flags WorldFlags, onChunk ProseStreamHandler) (turnLLMOutput, string, error) {
	if onChunk != nil {
		_ = onChunk(prose)
	}
	if len(actions) == 0 {
		actions = defaultAgentSuggestedActions(flags)
	}
	return turnLLMOutput{
		Prose:            prose,
		SuggestedActions: actions,
	}, "agent_llm", nil
}

func buildAgentPrompt(ctx context.Context, st Store, snap *SessionSnapshot, state TurnState, action string, toolNotes []string, step int) string {
	toolsDoc := worldToolsSchemaDoc()
	var notesBlock string
	if len(toolNotes) > 0 {
		notesBlock = "【工具已执行结果】\n" + strings.Join(toolNotes, "\n") + "\n\n"
	}
	memBlock := buildMemoryBlock(ctx, st, snap.UserID, state.NPCs)
	return fmt.Sprintf(`你是开放世界「迷雾小镇」的世界导演。数据库即世界：先调工具查/改状态，再写叙事。

【原则】
1. 【当前世界快照】已在下方，通常无需再调 world_get_context
2. 移动/拾取/对话/事件 → 对应 world_* 工具
3. 工具完成后在 prose 写 150-260 字中文小说（含 NPC 台词）
4. 禁止列表报幕、禁止复读场景描述原文

【工具】
%s

%s%s%s
【位置】%s
【玩家行动】%s
【Agent 步数】%d/%d

只输出 JSON，不要 markdown：
{"thought":"…","tool_calls":[],"prose":"","suggested_actions":["…"],"favor_deltas":{}}

有 tool_calls 时 prose 留空；无 tool_calls 时 prose 必须是完整叙事（示例：「你蹲下身，指尖触到冰凉的石面——老人在不远处抬眼。」）。`,
		toolsDoc,
		snap.HistoryBlock,
		memBlock,
		notesBlock,
		state.Scene.Name,
		action,
		step+1,
		agentMaxSteps,
	)
}

// WorldToolCall Agent 请求执行的世界工具。
type WorldToolCall struct {
	Name      string                 `json:"name"`
	Arguments map[string]interface{} `json:"arguments"`
}

// agentTurnOutput ReAct 回合：先调工具改 DB，再输出叙事。
type agentTurnOutput struct {
	Thought          string          `json:"thought"`
	ToolCalls        []WorldToolCall `json:"tool_calls"`
	Prose            string          `json:"prose"`
	SuggestedActions []string        `json:"suggested_actions"`
	FavorDeltas      map[string]int  `json:"favor_deltas"`
}

// worldToolContext 工具执行上下文（DB = 世界）。
type worldToolContext struct {
	ctx    context.Context
	st     Store
	deps   TurnDeps
	userID uint
	snap   *SessionSnapshot
	state  *TurnState
	notes  []string
}

func worldToolsSchemaDoc() string {
	return `- world_get_context：查询当前场景、NPC、背包、可见物品、近期事件（无参数）
- world_move：{"destination":"旅人酒馆"} 或 {"direction":"东边"} 移动玩家
- world_pickup：{"item_name":"石头"} 拾取入背包
- world_talk：{"npc_name":"老人"} 开始/锁定与 NPC 对话
- world_emit_event：{"scene":"迷雾小镇","summary":"钟楼传来异响","event_type":"discovery"} 登记世界事件
- world_set_npc_activity：{"npc_name":"老人","activity":"…"} 更新 NPC 行为`
}

func executeWorldTool(wctx *worldToolContext, call WorldToolCall) (string, error) {
	name := strings.TrimSpace(call.Name)
	args := call.Arguments
	if args == nil {
		args = map[string]interface{}{}
	}
	switch name {
	case "world_get_context":
		return wctx.toolGetContext()
	case "world_move":
		dest, _ := args["destination"].(string)
		dir, _ := args["direction"].(string)
		action := dest
		if action == "" {
			action = "前往" + dir
		}
		return wctx.toolMove(action)
	case "world_pickup":
		item, _ := args["item_name"].(string)
		return wctx.toolPickup(item)
	case "world_talk":
		npc, _ := args["npc_name"].(string)
		return wctx.toolTalk(npc)
	case "world_emit_event":
		scene, _ := args["scene"].(string)
		summary, _ := args["summary"].(string)
		typ, _ := args["event_type"].(string)
		return wctx.toolEmitEvent(scene, typ, summary)
	case "world_set_npc_activity":
		npc, _ := args["npc_name"].(string)
		act, _ := args["activity"].(string)
		return wctx.toolSetNpcActivity(npc, act)
	default:
		return "", fmt.Errorf("unknown tool %q", name)
	}
}

func (w *worldToolContext) toolGetContext() (string, error) {
	s := w.state
	inv, _ := w.st.ListInventoryItems(w.ctx, w.snap.Session.ID)
	items, _ := w.st.ListSceneItems(w.ctx, w.snap.Session.ID, s.Scene.ID)
	var b strings.Builder
	fmt.Fprintf(&b, "场景【%s】：%s\n", s.Scene.Name, s.Scene.Description)
	fmt.Fprintf(&b, "出口：%s\n", strings.Join(decodeExits(s.Scene.ExitsJSON), "、"))
	for _, npc := range s.NPCs {
		fmt.Fprintf(&b, "NPC %s（%s）\n", npc.Name, npc.Persona)
	}
	if len(inv) == 0 {
		b.WriteString("背包：空\n")
	} else {
		b.WriteString("背包：")
		for _, it := range inv {
			b.WriteString(it.Name + " ")
		}
		b.WriteString("\n")
	}
	if len(items) > 0 {
		b.WriteString("场景物品：")
		for _, it := range items {
			b.WriteString(it.Name + " ")
		}
		b.WriteString("\n")
	}
	for _, ev := range listRecentEventSummaries(w.ctx, w.st, w.snap.Session.ID, 5) {
		b.WriteString("近期事件：" + ev + "\n")
	}
	return b.String(), nil
}

func (w *worldToolContext) toolMove(action string) (string, error) {
	newScene, newNpcs, moved, err := tryExploreNewArea(
		w.ctx, w.st, w.deps, &w.state.Session, w.state.Scene, action, &w.state.Flags,
	)
	if err != nil {
		return "", err
	}
	if !moved {
		return "移动未成功：请给出更明确的目的地", nil
	}
	w.state.Scene = newScene
	w.state.NPCs = newNpcs
	w.state.Session.SceneID = newScene.ID
	w.state.Moved = true
	w.state.Flags.InDialogue = false
	w.state.Flags.LastTalkNPC = ""
	w.snap.Scene = newScene
	return fmt.Sprintf("已移动到【%s】", newScene.Name), nil
}

func (w *worldToolContext) toolPickup(itemName string) (string, error) {
	item, created, err := executePickup(w.ctx, w.st, w.snap, w.state, itemName)
	if err != nil {
		return "", err
	}
	if item.Name == "" {
		return "拾取失败：未指明物品", nil
	}
	if created {
		return fmt.Sprintf("已创建并拾取【%s】", item.Name), nil
	}
	return fmt.Sprintf("已拾取【%s】", item.Name), nil
}

func (w *worldToolContext) toolTalk(npcName string) (string, error) {
	npcName = strings.TrimSpace(npcName)
	if npcName == "" {
		npcName = pickTalkTarget(npcViewsFromModels(w.state.NPCs, w.snap.Favor), w.state.Scene.Name)
	}
	w.state.Flags.InDialogue = true
	w.state.Flags.LastTalkNPC = npcName
	w.state.Flags.PlayerFocus = npcName
	return fmt.Sprintf("开始与【%s】对话", npcName), nil
}

func (w *worldToolContext) toolEmitEvent(scene, eventType, summary string) (string, error) {
	summary = strings.TrimSpace(summary)
	if summary == "" {
		return "", fmt.Errorf("summary required")
	}
	if scene == "" {
		scene = w.state.Scene.Name
	}
	if err := persistWorldEvent(w.ctx, w.st, w.snap.Session.ID, scene, eventType, summary); err != nil {
		return "", err
	}
	return "已登记世界事件：" + summary, nil
}

func (w *worldToolContext) toolSetNpcActivity(npcName, activity string) (string, error) {
	if w.state.Flags.NpcActivity == nil {
		w.state.Flags.NpcActivity = map[string]string{}
	}
	w.state.Flags.NpcActivity[npcName] = activity
	return fmt.Sprintf("已更新 %s 的行为", npcName), nil
}

func defaultAgentSuggestedActions(flags WorldFlags) []string {
	if npc := strings.TrimSpace(flags.LastTalkNPC); npc != "" {
		return dialogueSuggestedActions(npc)
	}
	return []string{"观察周围", "和附近的人说话", "检查背包"}
}

func callAgentLLM(ctx context.Context, deps TurnDeps, prompt string) (string, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	return llminferenceChat(ctx, deps, modelName, prompt)
}

func llminferenceChat(ctx context.Context, deps TurnDeps, modelName, prompt string) (string, error) {
	return callAgentLLMRaw(ctx, deps, modelName, prompt)
}

