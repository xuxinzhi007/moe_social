package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/model"
	"backend/pkg/llminference"
)

type exploreLLMOutput struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Exits       []string `json:"exits"`
	NPCs        []struct {
		Name    string `json:"name"`
		Persona string `json:"persona"`
	} `json:"npcs"`
	Secret string `json:"secret"`
}

type travelTarget struct {
	Direction string
	Name      string
}

func tryExploreNewArea(ctx context.Context, st Store, deps TurnDeps, sess *model.GameSession, scene model.GameScene, action string, flags *WorldFlags) (model.GameScene, []model.GameNpc, bool, error) {
	exits := decodeExits(scene.ExitsJSON)
	target, ok := parseTravelTarget(action, exits)
	if !ok {
		return scene, nil, false, nil
	}
	targetName := strings.TrimSpace(target.Name)
	if targetName == "" {
		targetName = sceneNameFromDirection(target.Direction)
	}

	if existing, found, err := st.FindSceneByName(ctx, targetName); err != nil {
		return scene, nil, false, err
	} else if found {
		npcs, err := st.ListNpcsByScene(ctx, existing.ID)
		if err != nil {
			return scene, nil, false, err
		}
		flags.VisitedScenes = appendUnique(flags.VisitedScenes, existing.Name)
		flags.PlayerFocus = existing.Name
		return existing, npcs, true, nil
	}

	gen, err := generateAreaForTarget(ctx, deps, scene.Name, target, *flags)
	if err != nil {
		return scene, nil, false, err
	}
	exitsJSON, _ := json.Marshal(gen.Exits)
	newScene := &model.GameScene{
		Name:        gen.Name,
		Description: gen.Description,
		ExitsJSON:   string(exitsJSON),
		IsSeed:      false,
	}
	if err := st.CreateScene(ctx, newScene); err != nil {
		return scene, nil, false, err
	}
	var npcs []model.GameNpc
	for _, n := range gen.NPCs {
		npc := model.GameNpc{
			SceneID:          newScene.ID,
			Name:             strings.TrimSpace(n.Name),
			Persona:          strings.TrimSpace(n.Persona),
			BaseFavorability: 50,
		}
		if npc.Name == "" {
			continue
		}
		if err := st.CreateNpc(ctx, &npc); err != nil {
			return scene, nil, false, err
		}
		npcs = append(npcs, npc)
		if flags.NpcActivity == nil {
			flags.NpcActivity = map[string]string{}
		}
		flags.NpcActivity[npc.Name] = "刚刚出现在此地的陌生人"
	}
	flags.VisitedScenes = appendUnique(flags.VisitedScenes, gen.Name)
	flags.Discovered = appendUnique(flags.Discovered, gen.Secret)
	flags.PlayerFocus = gen.Name
	return *newScene, npcs, true, nil
}

func parseTravelTarget(action string, exits []string) (travelTarget, bool) {
	action = strings.TrimSpace(action)
	if action == "" {
		return travelTarget{}, false
	}
	lower := strings.ToLower(action)

	destName := extractDestinationName(action)
	if destName != "" {
		for _, exit := range exits {
			if strings.Contains(exit, destName) {
				return travelTarget{
					Direction: directionFromExitLabel(exit),
					Name:      normalizeDestinationName(destName),
				}, true
			}
		}
		if name, ok := knownDestinationName(destName); ok {
			return travelTarget{Name: name, Direction: detectTravelDirection(action, exits)}, true
		}
		if strings.Contains(destName, "海") {
			return travelTarget{Name: "海边码头", Direction: "远处"}, true
		}
		return travelTarget{Name: destName, Direction: ""}, true
	}

	for _, exit := range exits {
		label := exitLabelName(exit)
		if label != "" && strings.Contains(action, label) {
			return travelTarget{
				Direction: directionFromExitLabel(exit),
				Name:      normalizeDestinationName(label),
			}, true
		}
	}

	known := []struct {
		key  string
		name string
	}{
		{"旅人酒馆", "旅人酒馆"},
		{"酒馆", "旅人酒馆"},
		{"早市", "早市街"},
		{"教堂", "古老教堂"},
		{"森林", "迷雾森林"},
		{"海边", "海边码头"},
		{"码头", "海边码头"},
	}
	for _, item := range known {
		if strings.Contains(action, item.key) {
			return travelTarget{Name: item.name, Direction: detectTravelDirection(action, exits)}, true
		}
	}

	dir := detectTravelDirection(action, exits)
	if dir != "" {
		return travelTarget{Direction: dir, Name: sceneNameFromDirection(dir)}, true
	}
	_ = lower
	return travelTarget{}, false
}

func extractDestinationName(action string) string {
	for _, prefix := range []string{"前往", "去到", "进入", "走向", "去"} {
		if idx := strings.Index(action, prefix); idx >= 0 {
			rest := strings.TrimSpace(action[idx+len(prefix):])
			for _, sep := range []string{"：", ":", "—", "-", " "} {
				if parts := strings.SplitN(rest, sep, 2); len(parts) == 2 && strings.TrimSpace(parts[1]) != "" {
					return strings.TrimSpace(parts[1])
				}
			}
			if rest != "" && !strings.Contains(rest, "方向") {
				return rest
			}
		}
	}
	return ""
}

func exitLabelName(exit string) string {
	for _, sep := range []string{"：", ":", "—"} {
		if parts := strings.SplitN(exit, sep, 2); len(parts) == 2 {
			return strings.TrimSpace(parts[1])
		}
	}
	return strings.TrimSpace(exit)
}

func directionFromExitLabel(exit string) string {
	for dir, keys := range map[string][]string{
		"东边": {"东"},
		"南边": {"南"},
		"西边": {"西"},
		"北边": {"北"},
	} {
		for _, k := range keys {
			if strings.Contains(exit, k) {
				return dir
			}
		}
	}
	return ""
}

func normalizeDestinationName(name string) string {
	name = strings.TrimSpace(name)
	switch {
	case strings.Contains(name, "酒馆"):
		return "旅人酒馆"
	case strings.Contains(name, "早市"):
		return "早市街"
	case strings.Contains(name, "教堂"):
		return "古老教堂"
	case strings.Contains(name, "森林"):
		return "迷雾森林"
	case strings.Contains(name, "海"):
		return "海边码头"
	default:
		return name
	}
}

func knownDestinationName(name string) (string, bool) {
	n := normalizeDestinationName(name)
	switch n {
	case "旅人酒馆", "早市街", "古老教堂", "迷雾森林", "海边码头":
		return n, true
	default:
		return n, n != name || strings.Contains(name, "海")
	}
}

func detectTravelDirection(action string, exits []string) string {
	lower := strings.ToLower(action)
	keywords := map[string][]string{
		"东边": {"东边", "东侧", "向东", "往东", "东面"},
		"南边": {"南边", "南侧", "向南", "往南", "南面"},
		"西边": {"西边", "西侧", "向西", "往西", "西面", "森林"},
		"北边": {"北边", "北侧", "向北", "往北", "北面", "集市", "早市"},
	}
	for dir, keys := range keywords {
		for _, k := range keys {
			if strings.Contains(lower, k) || strings.Contains(action, k) {
				return dir
			}
		}
	}
	if strings.Contains(action, "前往") || strings.Contains(action, "走去") || strings.Contains(action, "进入") {
		for _, exit := range exits {
			for _, k := range []string{"东", "南", "西", "北"} {
				if strings.Contains(exit, k) && strings.Contains(action, k) {
					return directionFromExitLabel(exit)
				}
			}
		}
	}
	return ""
}

func sceneNameFromDirection(dir string) string {
	switch dir {
	case "东边":
		return "旅人酒馆"
	case "南边":
		return "古老教堂"
	case "西边":
		return "迷雾森林"
	case "北边":
		return "早市街"
	default:
		return "未知区域"
	}
}

func generateAreaForTarget(ctx context.Context, deps TurnDeps, fromScene string, target travelTarget, flags WorldFlags) (exploreLLMOutput, error) {
	name := strings.TrimSpace(target.Name)
	if name == "" {
		name = sceneNameFromDirection(target.Direction)
	}
	fallback := exploreFallback(fromScene, name, target.Direction, flags)
	if !deps.Inference.Ready() {
		return fallback, nil
	}
	label := target.Direction
	if label == "" {
		label = name
	}
	prompt := fmt.Sprintf(`为文字冒险游戏生成新区域 JSON（不要 markdown）：
从【%s】前往【%s】。
世界氛围：%s
格式：
{"name":"%s","description":"50-80字氛围描述","exits":["返回%s"],"npcs":[{"name":"","persona":""}],"secret":"一句隐藏秘密"}
要求奇幻小镇风格，中文，name 必须是「%s」。`, fromScene, label, flags.WorldMood, name, fromScene, name)
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = deps.Inference.DefaultModel
	}
	content, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "只输出合法 JSON。"},
		{Role: "user", Content: prompt},
	}, llminference.ChatOptions{Temperature: 0.9, MaxTokens: 512})
	if err != nil {
		return fallback, nil
	}
	content = stripJSONFence(content)
	var out exploreLLMOutput
	if json.Unmarshal([]byte(content), &out) != nil || strings.TrimSpace(out.Name) == "" {
		return fallback, nil
	}
	out.Name = name
	return out, nil
}

func exploreFallback(fromScene, name, direction string, flags WorldFlags) exploreLLMOutput {
	if direction == "" {
		direction = "前方"
	}
	return exploreLLMOutput{
		Name:        name,
		Description: fmt.Sprintf("你离开%s，向%s来到【%s】。%s与来时不同，像是世界的另一页被悄然翻开。", fromScene, direction, name, flags.WorldMood),
		Exits:       []string{fmt.Sprintf("返回%s", fromScene)},
		NPCs: []struct {
			Name    string `json:"name"`
			Persona string `json:"persona"`
		}{{Name: "过路人", Persona: "匆匆经过的镇民，似乎不愿多谈。"}},
		Secret: "此地的秘密尚未被揭开",
	}
}

func isPureTravelAction(action string) bool {
	_, ok := parseTravelTarget(action, nil)
	return ok
}

func exploreArrivalOutput(scene model.GameScene, npcs []NpcView, flags WorldFlags) turnLLMOutput {
	var npcHint string
	if len(npcs) > 0 {
		npcHint = fmt.Sprintf("你注意到 %s 也在附近。", npcs[0].Name)
	}
	prose := fmt.Sprintf("你抵达【%s】。%s %s", scene.Name, scene.Description, npcHint)
	exits := decodeExits(scene.ExitsJSON)
	suggested := make([]string, 0, 3)
	for _, exit := range exits {
		if len(suggested) >= 2 {
			break
		}
		suggested = append(suggested, "前往"+exitLabelName(exit))
	}
	if len(suggested) == 0 {
		suggested = []string{"观察周围", "和附近的人说话", "继续探索"}
	} else {
		suggested = append(suggested, "观察周围")
	}
	return turnLLMOutput{
		Prose: strings.TrimSpace(prose),
		FlagsPatch: map[string]interface{}{
			"player_focus":   scene.Name,
			"player_posture": "刚到达",
		},
		SuggestedActions: suggested,
		GameTime:         advanceGameTime(flags, scene.Name),
	}
}

func stripJSONFence(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}
