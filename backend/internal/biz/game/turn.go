package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/internal/platform/moelog"
	"backend/model"
	"backend/pkg/llminference"
)

type turnLLMLine struct {
	Type    string `json:"type"`
	Content string `json:"content"`
	Name    string `json:"name"`
}

type turnLLMOutput struct {
	Prose            string                 `json:"prose"`
	Narrative        []turnLLMLine            `json:"narrative"`
	GameTime         string                 `json:"game_time"`
	FavorDeltas      map[string]int         `json:"favor_deltas"`
	NewMemories      []turnLLMMemory          `json:"new_memories"`
	FlagsPatch       map[string]interface{} `json:"flags_patch"`
	NewScene         *turnLLMScene          `json:"new_scene"`
	NewNPCs          []turnLLMNpcSpawn      `json:"new_npcs"`
	NewItems         []turnLLMItemSpawn     `json:"new_items"`
	RandomEvent      *turnLLMEvent          `json:"random_event"`
	SuggestedActions []string               `json:"suggested_actions"`
}

type turnLLMMemory struct {
	NpcName    string `json:"npc_name"`
	MemoryText string `json:"memory_text"`
	Importance int    `json:"importance"`
}

// TurnDeps 回合引擎依赖。
type TurnDeps struct {
	Inference llminference.Config
	Model     string
}

// ActResult 玩家行动结果。
type ActResult struct {
	Narrative           []NarrativeLine
	Location            string
	GameTime            string
	OverallFavorability int32
	PlayerFocus         string
	NarrativeSource     string // llm_json | llm_prose | fallback
	LlmOnline           bool
	SuggestedActions    []string
	Inventory           []ItemView
	Npcs                []NpcView
}

func Act(ctx context.Context, st Store, deps TurnDeps, userIDRaw string, sessionID uint64, action string) (ActResult, error) {
	return RunTurn(ctx, st, deps, userIDRaw, sessionID, action, nil)
}

func persistActResult(
	ctx context.Context,
	st Store,
	userID uint,
	sess model.GameSession,
	scene model.GameScene,
	npcs []model.GameNpc,
	flags WorldFlags,
	favor map[string]int,
	output turnLLMOutput,
	lines []NarrativeLine,
	action string,
	narrativeSource string,
	llmOnline bool,
) (ActResult, error) {
	gameTime := strings.TrimSpace(output.GameTime)
	if gameTime == "" {
		gameTime = sess.GameTime
	}
	flags.mergePatch(output.FlagsPatch)
	advanceStoryArcs(&flags, output, output.FavorDeltas)

	npcByName := map[string]model.GameNpc{}
	for _, npc := range npcs {
		npcByName[npc.Name] = npc
	}
	for name, delta := range output.FavorDeltas {
		npc, ok := npcByName[strings.TrimSpace(name)]
		if !ok || delta == 0 {
			continue
		}
		key := fmt.Sprintf("%d", npc.ID)
		cur := npc.BaseFavorability
		if v, ok := favor[key]; ok {
			cur = v
		}
		cur = clamp(cur+delta, 0, 100)
		favor[key] = cur
	}

	for _, mem := range output.NewMemories {
		text := strings.TrimSpace(mem.MemoryText)
		if text == "" {
			continue
		}
		npc, ok := npcByName[strings.TrimSpace(mem.NpcName)]
		if !ok {
			continue
		}
		imp := mem.Importance
		if imp <= 0 {
			imp = 5
		}
		_ = st.CreateNpcMemory(ctx, &model.GameNpcMemory{
			PlayerID:   userID,
			NpcID:      npc.ID,
			MemoryText: text,
			Importance: imp,
		})
	}

	patch, _ := json.Marshal(map[string]interface{}{
		"favor_deltas": output.FavorDeltas,
		"flags_patch":  output.FlagsPatch,
	})
	narrativeJSON, _ := json.Marshal(lines)
	_ = st.CreateTurnLog(ctx, &model.GameTurnLog{
		SessionID:       sess.ID,
		UserAction:      action,
		SystemNarrative: string(narrativeJSON),
		StatePatchJSON:  string(patch),
	})
	_ = st.UpdateSession(ctx, sess.ID, map[string]interface{}{
		"scene_id":       sess.SceneID,
		"game_time":      gameTime,
		"npc_favor_json": encodeNpcFavor(favor),
		"flags_json":     encodeWorldFlags(flags),
	})

	updatedViews := npcViewsFromModels(npcs, favor)
	suggested := output.SuggestedActions
	if len(suggested) == 0 {
		suggested = defaultSuggestedActions(scene.Name, flags)
	}
	invRows, _ := st.ListInventoryItems(ctx, sess.ID)
	return ActResult{
		Narrative:           lines,
		Location:            scene.Name,
		GameTime:            gameTime,
		OverallFavorability: averageFavor(favor, updatedViews),
		PlayerFocus:         flags.PlayerFocus,
		NarrativeSource:     narrativeSource,
		LlmOnline:           llmOnline,
		SuggestedActions:    suggested,
		Inventory:           itemViewsFromModels(invRows),
		Npcs:                updatedViews,
	}, nil
}

func resolveTurnOutput(
	ctx context.Context,
	deps TurnDeps,
	ctxPrompt actPromptContext,
	action string,
	scene model.GameScene,
	npcViews []NpcView,
	flags WorldFlags,
	intent PlayerIntent,
) (turnLLMOutput, string) {
	if !deps.Inference.Ready() {
		moelog.Infof("game turn fallback: inference base url empty, action=%q", action)
		return fallbackTurn(action, intent, scene, npcViews, flags), "fallback"
	}

	candidates := turnModelCandidates(ctx, deps)
	var lastErr error
	for _, modelName := range candidates {
		tryDeps := deps
		tryDeps.Model = modelName

		if out, err := callTurnLLMJSON(ctx, tryDeps, ctxPrompt); err == nil {
			out = normalizeTurnOutput(out, flags, scene.Name)
			if isValidProse(out.Prose) {
				return out, "llm_json"
			}
		} else if err != nil {
			lastErr = err
		}

		if out, err := callTurnLLMProse(ctx, tryDeps, ctxPrompt); err == nil {
			out = normalizeTurnOutput(out, flags, scene.Name)
			if isValidProse(out.Prose) {
				return out, "llm_prose"
			}
		} else if err != nil {
			lastErr = err
		}
	}
	if lastErr != nil {
		moelog.Infof("game turn fallback: llm failed action=%q scene=%q base=%s err=%v",
			action, scene.Name, deps.Inference.BaseURL, lastErr)
	} else {
		moelog.Infof("game turn fallback: llm empty response action=%q scene=%q base=%s",
			action, scene.Name, deps.Inference.BaseURL)
	}
	out := fallbackTurn(action, intent, scene, npcViews, flags)
	if len(out.Prose) == 0 {
		lines := narrativeFromOutput(out, action)
		if len(lines) > 1 {
			out.Prose = lines[1].Content
		}
	}
	return out, "fallback"
}

type actPromptContext struct {
	sceneBlock string
	action     string
}

func buildActPromptContext(
	scene model.GameScene,
	npcs []NpcView,
	gameTime string,
	flags WorldFlags,
	memBlock string,
	intent PlayerIntent,
	inventory []model.GameWorldItem,
	sceneItems []model.GameWorldItem,
	action string,
	loreBlock string,
	arcBlock string,
	historyBlock string,
	dialogueBlock string,
) actPromptContext {
	var npcLines strings.Builder
	for _, npc := range npcs {
		npcLines.WriteString(fmt.Sprintf("- %s（好感 %d）：%s\n", npc.Name, npc.Favorability, npc.Persona))
	}
	exits := strings.Join(decodeExits(scene.ExitsJSON), "；")
	block := fmt.Sprintf(`%s%s%s%s%s【当前场景】%s
【描述】%s
【出口】%s
【时间】%s
【玩家位置/关注】%s（%s）
【世界氛围】%s
【故事阶段】%d
【已探索区域】%s
%s%s【NPC】
%s
%s`,
		historyBlock,
		dialogueBlock,
		loreBlock,
		arcBlock,
		intentBlock(intent),
		scene.Name, scene.Description, exits, gameTime,
		flags.PlayerFocus, flags.PlayerPosture, flags.WorldMood, flags.StoryPhase,
		strings.Join(flags.VisitedScenes, "、"),
		inventoryBlock(flags, inventory),
		sceneItemsBlock(sceneItems),
		npcLines.String(), memBlock+npcActivityBlock(flags))
	return actPromptContext{sceneBlock: block, action: action}
}

func buildActPromptJSON(ctx actPromptContext) string {
	return fmt.Sprintf(`你是开放世界文字冒险的「世界生成引擎」。玩家输入任何行动，你都要让世界产生合理、具体、可延续的变化。

【开放世界规则】
1. 玩家可以去任何合理方向、遇见新的人、发现新物品——若不存在则由你即时生成并写入 JSON
2. 先写 prose 叙事（150-280字），再更新状态字段
3. 必须承接【近期剧情】与【当前对话对象】，禁止把【描述】原文复制到 prose
4. 约每 4-6 回合可触发一次 random_event（环境/遭遇/发现），不要每回合都触发
5. suggested_actions 给出 3 条玩家接下来可尝试的具体行动（中文短句）

%s
【玩家行动】%s

严格输出 JSON（无 markdown）：
{
  "prose": "真实发生的故事正文",
  "game_time": "例如 上午 10:30",
  "favor_deltas": {"NPC名": 整数},
  "new_memories": [{"npc_name":"","memory_text":"","importance":1-10}],
  "new_scene": {"name":"","description":"","scene_type":"","exits":[],"move_player": true},
  "new_npcs": [{"name":"","persona":"","role":""}],
  "new_items": [{"name":"","description":"","takeable": true, "picked_up": false}],
  "random_event": {"type":"weather/encounter/discovery","description":""},
  "suggested_actions": ["行动1","行动2","行动3"],
  "flags_patch": {
    "player_focus": "",
    "player_posture": "",
    "world_mood": "",
    "story_phase": 0,
    "npc_activity": {"NPC名":""}
  }
}

说明：若玩家前往新区域，填 new_scene 且 move_player=true；若只是观察当前区域，new_scene 可省略或为 null。`, ctx.sceneBlock, ctx.action)
}

func buildActPromptProse(ctx actPromptContext) string {
	return fmt.Sprintf(`你是文字冒险游戏的叙事引擎。玩家在一个可自由行动的世界里。

【规则】
1. 先写行动结果与环境变化，再嵌入 NPC 对话
2. 只输出一段 150-280 字的中文小说正文
3. 必须承接近期剧情，禁止重复场景描述原文
4. 禁止输出 JSON、markdown、字段名或任何结构化格式

%s
【玩家行动】%s

请直接输出小说段落：`, ctx.sceneBlock, ctx.action)
}

func turnModelCandidates(ctx context.Context, deps TurnDeps) []string {
	seen := map[string]struct{}{}
	var out []string
	add := func(name string) {
		name = strings.TrimSpace(name)
		if name == "" {
			return
		}
		if _, ok := seen[name]; ok {
			return
		}
		seen[name] = struct{}{}
		out = append(out, name)
	}
	add(deps.Model)
	add(deps.Inference.DefaultModel)
	if models, err := llminference.ListModels(ctx, deps.Inference); err == nil {
		for _, id := range models {
			add(id)
		}
	}
	if len(out) == 0 {
		add("qwen2")
	}
	return out
}

func clamp(v, min, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}

func callTurnLLMJSON(ctx context.Context, deps TurnDeps, ctxPrompt actPromptContext) (turnLLMOutput, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	content, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "你是 JSON 格式的文字世界叙事引擎。只输出合法 JSON，prose 必须是真实叙事正文。"},
		{Role: "user", Content: buildActPromptJSON(ctxPrompt)},
	}, llminference.ChatOptions{Temperature: 0.88, MaxTokens: 1200})
	if err != nil {
		return turnLLMOutput{}, err
	}
	out, ok := parseTurnLLMContent(content)
	if !ok {
		return turnLLMOutput{}, fmt.Errorf("invalid llm json response")
	}
	return out, nil
}

func callTurnLLMProse(ctx context.Context, deps TurnDeps, ctxPrompt actPromptContext) (turnLLMOutput, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	content, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "你是文字冒险叙事引擎。只输出一段中文小说正文，禁止 JSON。"},
		{Role: "user", Content: buildActPromptProse(ctxPrompt)},
	}, llminference.ChatOptions{Temperature: 0.9, MaxTokens: 900})
	if err != nil {
		return turnLLMOutput{}, err
	}
	out, ok := parseTurnLLMContent(content)
	if !ok {
		return turnLLMOutput{}, fmt.Errorf("invalid llm prose response")
	}
	return out, nil
}

func narrativeFromOutput(output turnLLMOutput, playerAction string) []NarrativeLine {
	out := []NarrativeLine{{Type: "action_echo", Content: playerAction}}
	prose := strings.TrimSpace(output.Prose)
	if parsed, ok := parseTurnLLMContent(prose); ok && isValidProse(parsed.Prose) {
		prose = parsed.Prose
	}
	if isValidProse(prose) {
		out = append(out, NarrativeLine{Type: "prose", Content: prose})
		return out
	}
	for _, line := range output.Narrative {
		t := strings.TrimSpace(line.Type)
		c := strings.TrimSpace(line.Content)
		if c == "" {
			continue
		}
		if t == "" || t == "system" || t == "npc" {
			t = "prose"
		}
		out = append(out, NarrativeLine{Type: t, Content: c, Name: strings.TrimSpace(line.Name)})
	}
	return mergeProseLines(out)
}

func mergeProseLines(lines []NarrativeLine) []NarrativeLine {
	if len(lines) <= 2 {
		return lines
	}
	var merged []NarrativeLine
	var buf strings.Builder
	flush := func() {
		if buf.Len() == 0 {
			return
		}
		merged = append(merged, NarrativeLine{Type: "prose", Content: strings.TrimSpace(buf.String())})
		buf.Reset()
	}
	for _, line := range lines {
		if line.Type == "action_echo" {
			flush()
			merged = append(merged, line)
			continue
		}
		if line.Type == "prose" || line.Type == "system" || line.Type == "npc" {
			if buf.Len() > 0 {
				buf.WriteString("\n\n")
			}
			buf.WriteString(line.Content)
			continue
		}
		flush()
		merged = append(merged, line)
	}
	flush()
	return merged
}

func fallbackTurn(action string, intent PlayerIntent, scene model.GameScene, npcs []NpcView, flags WorldFlags) turnLLMOutput {
	lower := strings.ToLower(action)
	sceneName := scene.Name
	var prose string
	patch := map[string]interface{}{}
	deltas := map[string]int{}
	memories := []turnLLMMemory{}

	switch {
	case strings.Contains(lower, "观察") || strings.Contains(lower, "看看") || strings.Contains(lower, "周围") || intent.Type == "observe":
		if strings.Contains(sceneName, "酒馆") || strings.Contains(sceneName, "旅人") {
			prose = `你放慢呼吸，细看旅人酒馆：吊灯把暖光铺在木桌上，角落酒客用帽檐遮住脸，吧台后一排风干的草药，侧门通向后巷的窄廊里透着湿冷的风。老板擦杯子的节奏忽然慢了一拍——像察觉到了你的目光。`
			patch["player_focus"] = "酒馆内部"
		} else {
			prose = fmt.Sprintf(`你停下脚步，让感官慢慢适应%s的空气。晨雾在脚边流动，广场中央的古老钟楼在雾中若隐若现——第二层有一扇破窗。东边旅人酒馆的招牌轻轻摇晃，南边教堂尖顶刺破雾气，西边森林小径被落叶覆盖。长椅上，老人正用烟斗敲了敲膝盖，似乎注意到你在打量这一切。`, sceneName)
			patch["player_focus"] = "广场全景"
		}
		patch["player_posture"] = "驻足观察"

	case strings.Contains(lower, "钟楼"):
		prose = `你眯起眼睛望向钟楼。雾中的尖顶时隐时现，你注意到第二层有一扇窗户是破的，像被人从里面推开过。一阵冷风拂过，你后颈泛起鸡皮疙瘩。老人顺着你的目光看去，声音低了下来：「你看到那座钟了吗？每天午夜，它都会敲响十三下……」`
		patch["player_focus"] = "古老钟楼"
		patch["story_phase"] = 1
		deltas["老人"] = 2

	case strings.Contains(lower, "走向") && strings.Contains(lower, "老人") ||
		strings.Contains(lower, "坐到") && strings.Contains(lower, "老人") ||
		(strings.Contains(lower, "老人") && (strings.Contains(lower, "交谈") || strings.Contains(lower, "对话") || strings.Contains(lower, "说话"))):
		if strings.Contains(lower, "坐") {
			prose = `你走到长椅旁，缓缓坐下。老人往旁边挪了挪，给你腾出位置。你闻到烟草和旧木头的气味混在晨雾里。他侧过脸，用浑浊的眼睛打量着你，说：「年轻人，你是外地来的吧？这镇子已经很久没有新面孔了。」`
			patch["player_posture"] = "坐在老人旁边"
		} else {
			prose = `你穿过晨雾，脚步声在空荡的广场上回响，走到长椅前。老人抬起头，烟斗停在半空，用浑浊的眼睛打量着你。沉默片刻后，他开口了：「年轻人，你是外地来的吧？这镇子已经很久没有新面孔了。」`
			patch["player_posture"] = "站立在老人面前"
		}
		patch["player_focus"] = "老人"
		patch["last_talk_npc"] = "老人"
		patch["npc_activity"] = map[string]interface{}{"老人": "与你交谈，语气谨慎"}
		deltas["老人"] = 1

	case strings.Contains(lower, "乞丐") || strings.Contains(lower, "帮助"):
		prose = `你蹲下身，将一点善意递给角落里的乞丐。他抬起头，眼中闪过一丝惊讶，随即低下了头。「谢谢……我会记住你的。」他小声说，同时飞快地扫了一眼广场——像在确认没有人在看。`
		patch["player_focus"] = "乞丐"
		patch["player_posture"] = "蹲下"
		deltas["乞丐"] = 5
		memories = append(memories, turnLLMMemory{NpcName: "乞丐", MemoryText: "玩家在广场帮助了乞丐", Importance: 6})

	case strings.Contains(lower, "酒馆"):
		prose = `你推开旅人酒馆的木门，暖气和麦酒的气味扑面而来，与外面的晨雾形成鲜明对比。老板从吧台后抬起头，手还在擦杯子：「欢迎，旅人。想喝点什么？」`
		patch["player_focus"] = "旅人酒馆"

	case strings.Contains(lower, "为什么") && strings.Contains(lower, "迷雾"):
		prose = `你的问题在晨雾中悬停了一秒。老人没有立刻回答，而是用烟斗指向钟楼的方向。「看到那座钟了吗？」他的声音压得很低，「十三年前的一个雨夜之后，这镇子就再也没能真正散去雾……」`
		patch["player_focus"] = "老人"
		patch["story_phase"] = 2
		deltas["老人"] = 3

	case intent.Type == "talk" || strings.Contains(lower, "说话") || strings.Contains(lower, "交谈") ||
		strings.Contains(lower, "搭话") || (strings.Contains(lower, "附近") && strings.Contains(lower, "人")):
		target := pickTalkTarget(npcs, sceneName)
		prose = fmt.Sprintf(`你走向%s，对方从手头的事里抬起头。空气里有一瞬的停顿，随后%s开口了：「……你找我有事？」`, target, target)
		patch["player_focus"] = target
		patch["last_talk_npc"] = target
		patch["npc_activity"] = map[string]interface{}{target: "正在与你交谈"}
		if target != "附近的酒客" && target != "路人" {
			deltas[target] = 1
		}

	case intent.Type == "travel" || strings.Contains(lower, "探索") || strings.Contains(lower, "方向"):
		dir := strings.TrimSpace(intent.Direction)
		if dir == "" {
			dir = "门外"
		}
		if strings.Contains(sceneName, "酒馆") || strings.Contains(sceneName, "旅人") {
			prose = fmt.Sprintf(`你离开吧台，朝%s走去。侧门吱呀一声打开，湿冷的空气涌进来，与酒馆内的麦酒暖气形成鲜明对比。`, dir)
		} else {
			prose = fmt.Sprintf(`你整理了一下装备，朝%s迈出脚步。%s的轮廓在视野里缓缓变化——风带来新的气味，脚下的路也不再是刚才的模样。`, dir, sceneName)
		}
		patch["player_posture"] = "移动中"
		patch["player_focus"] = dir + "方向"

	case strings.Contains(sceneName, "酒馆") || strings.Contains(sceneName, "旅人"):
		switch {
		case strings.Contains(lower, "坐"):
			prose = `你在吧台边找到一张空位坐下。木椅发出轻微的吱呀声，老板把一杯还冒着热气的饮品推到你面前，眼神里带着打量：「第一次来？这镇上的事，最好别问太多。」`
			patch["player_posture"] = "坐在吧台"
		case strings.Contains(lower, "有人") || strings.Contains(lower, "吗"):
			prose = `你扬声问了一句。酒馆里几个酒客抬起头，又很快低下。老板从吧台后探出身：「有人，但不多。你是外地来的吧？想打听什么？」`
			patch["player_focus"] = "酒馆老板"
		case strings.Contains(lower, "喝") || strings.Contains(lower, "点"):
			prose = `老板擦了擦杯子，给你倒了半杯琥珀色的液体。「今天的麦酒刚酿好，」他说，「小心点，这镇上的酒……有时候会让人看见不该看的东西。」`
		case strings.Contains(lower, "你好") || strings.Contains(lower, "嗨") || strings.Contains(lower, "hello"):
			prose = `老板抬头看了你一眼，继续擦着手里的杯子，语气不冷不热：「旅人，想喝点什么就开口。别站门口挡风。」`
			patch["player_focus"] = "酒馆老板"
		case strings.Contains(lower, "什么") || strings.Contains(lower, "?") || strings.Contains(lower, "？"):
			prose = `你的话在暖融融的酒馆里显得有些突兀。老板停下手里的活，眯眼打量你：「这镇子的事，问多了未必有好事。先坐下，慢慢说。」`
			patch["player_focus"] = "酒馆老板"
		default:
			prose = fmt.Sprintf(`你在%s里继续行动。吊灯把暖光铺在木桌上，远处有人低声碰杯，近处老板仍在擦拭杯子——一切看似平常，却总觉得有目光在暗处打量你。`, sceneName)
		}
		patch["player_focus"] = "旅人酒馆"

	default:
		switch intent.Type {
		case "travel":
			prose = fmt.Sprintf(`你整理了一下装备，在%s里寻找可以前进的路。%s`, sceneName, flags.WorldMood)
			patch["player_posture"] = "移动中"
		case "observe":
			prose = fmt.Sprintf(`你环顾%s，试图从%s中捕捉更多细节。`, sceneName, flags.WorldMood)
			patch["player_posture"] = "驻足观察"
		case "inventory":
			prose = "你下意识地摸了摸背包，里面暂时没有特别的东西。"
			patch["player_focus"] = "背包"
		case "talk":
			target := pickTalkTarget(npcs, sceneName)
			prose = fmt.Sprintf(`你试图与%s搭话，对方似乎还在忙别的事。`, target)
		default:
			prose = fmt.Sprintf(`你尝试「%s」。%s里的一切似乎对你的行动有所回应，但还需要更具体的指令才能产生变化。`, action, sceneName)
		}
	}

	suggested := fallbackSuggestedActions(intent, sceneName, flags)
	return turnLLMOutput{
		Prose:            prose,
		GameTime:         advanceGameTime(flags, sceneName),
		FavorDeltas:      deltas,
		NewMemories:      memories,
		FlagsPatch:       patch,
		SuggestedActions: suggested,
	}
}

func pickTalkTarget(npcs []NpcView, sceneName string) string {
	if len(npcs) > 0 {
		return npcs[0].Name
	}
	if strings.Contains(sceneName, "酒馆") {
		return "酒馆老板"
	}
	return "附近的酒客"
}

func fallbackSuggestedActions(intent PlayerIntent, sceneName string, flags WorldFlags) []string {
	_ = flags
	if strings.Contains(sceneName, "酒馆") {
		return []string{"向老板点一杯麦酒", "打听镇上的传闻", "离开酒馆去广场"}
	}
	switch intent.Type {
	case "observe":
		return []string{"仔细查看钟楼", "走向旅人酒馆", "和老人搭话"}
	case "talk":
		return []string{"继续追问", "换个话题", "观察对方反应"}
	case "travel":
		return []string{"继续往前走", "返回广场", "寻找可以休息的地方"}
	}
	return []string{"观察周围", "和附近的人说话", "往一个方向探索"}
}

func lastProseFromLines(lines []NarrativeLine) string {
	for i := len(lines) - 1; i >= 0; i-- {
		if lines[i].Type == "prose" {
			return strings.TrimSpace(lines[i].Content)
		}
	}
	return ""
}

func lastSessionProse(ctx context.Context, st Store, sessionID uint) string {
	logs, err := st.ListTurnLogs(ctx, sessionID, 1)
	if err != nil || len(logs) == 0 {
		return ""
	}
	var lines []NarrativeLine
	if json.Unmarshal([]byte(logs[0].SystemNarrative), &lines) != nil {
		return ""
	}
	return lastProseFromLines(lines)
}

func varyRepeatedProse(prose string, intent PlayerIntent, turnCount int) string {
	prose = strings.TrimSpace(prose)
	if prose == "" {
		return prose
	}
	suffix := map[string]string{
		"talk":    " 对方似乎还想说什么，却又把话咽了回去。",
		"travel":  " 你注意到路边有些不寻常的痕迹。",
		"observe": " 这次你发现了先前忽略的细节。",
		"interact": " 世界的回应与刚才略有不同。",
	}
	if s, ok := suffix[intent.Type]; ok {
		return prose + s
	}
	return fmt.Sprintf("%s（第 %d 回合，局势悄然变化。）", prose, turnCount)
}

func advanceGameTime(flags WorldFlags, sceneName string) string {
	// 简单时间推进
	if strings.Contains(flags.WorldMood, "午") {
		return "下午 2:30"
	}
	if sceneName != seedSceneName {
		return "上午 10:45"
	}
	return "上午 10:20"
}

func buildMemoryBlock(ctx context.Context, st Store, playerID uint, npcs []model.GameNpc) string {
	var b strings.Builder
	for _, npc := range npcs {
		memories, err := st.ListNpcMemories(ctx, playerID, npc.ID, 5)
		if err != nil || len(memories) == 0 {
			continue
		}
		b.WriteString(fmt.Sprintf("\n【%s 对玩家的记忆】\n", npc.Name))
		for _, m := range memories {
			b.WriteString("- ")
			b.WriteString(m.MemoryText)
			b.WriteString("\n")
		}
	}
	return b.String()
}
