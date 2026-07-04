package gamebiz

import (
	"fmt"
	"strings"

	"backend/model"
)

// tryNarratorRuleOutput 小模型管不了逻辑：由 Go 判定事实，必要时跳过 LLM。
func tryNarratorRuleOutput(cmd Command, scene model.GameScene) (turnLLMOutput, string, bool) {
	raw := strings.TrimSpace(cmd.Raw)
	if raw == "" {
		return turnLLMOutput{}, "", false
	}
	if isMetaQuestion(raw) {
		return metaQuestionOutput(scene), "go_meta", true
	}
	if isPlayerDenial(raw) {
		return playerDenialOutput(scene), "go_denial", true
	}
	if cmd.Kind == CmdFreeform && isImpossibleFreeformAction(raw) {
		return impossibleActionOutput(raw, scene), "go_impossible", true
	}
	return turnLLMOutput{}, "", false
}

func metaQuestionOutput(scene model.GameScene) turnLLMOutput {
	_ = scene
	return turnLLMOutput{
		Prose: "我是这个文字世界里的叙事助手，负责根据你的行动描写场景；故事里的「你」是冒险者，不是我。想继续冒险的话，可以说说你想做什么。",
		SuggestedActions: []string{
			"观察周围",
			"和附近的人说话",
			"往一个方向探索",
		},
	}
}

func playerDenialOutput(scene model.GameScene) turnLLMOutput {
	return turnLLMOutput{
		Prose: fmt.Sprintf("你摇了摇头。%s的晨雾轻轻晃动，仿佛刚才的误会被风吹散。接下来你想做什么？", strings.TrimSpace(scene.Name)),
		SuggestedActions: []string{
			"观察周围",
			"和老人搭话",
			"前往旅人酒馆",
		},
	}
}

func impossibleActionOutput(action string, scene model.GameScene) turnLLMOutput {
	act := trimRunes(strings.TrimSpace(action), 24)
	sceneName := strings.TrimSpace(scene.Name)
	if sceneName == "" {
		sceneName = "这里"
	}
	exits := decodeExits(scene.ExitsJSON)
	dirHint := "可见的出口"
	if len(exits) > 0 {
		dirHint = strings.Join(exits, "、")
	}
	return turnLLMOutput{
		Prose: fmt.Sprintf(
			"你脑海里闪过「%s」的念头，但%s的现实把你拉回脚下——晨雾、钟楼和%s才是此刻能触及的。",
			act, sceneName, dirHint,
		),
		SuggestedActions: []string{
			"观察周围",
			"和附近的人说话",
			"往一个方向探索",
		},
	}
}

func isImpossibleFreeformAction(action string) bool {
	a := strings.TrimSpace(action)
	for _, k := range []string{
		"月球", "火星", "太阳", "太空", "宇宙", "天上", "天空", "飞翔", "飞行",
		"传送", "瞬移", "穿越到", "回到现实", "退出游戏",
	} {
		if strings.Contains(a, k) {
			return true
		}
	}
	return false
}

func isPlayerDenial(action string) bool {
	a := strings.TrimSpace(action)
	if utf8RuneCount(a) > 16 {
		return false
	}
	for _, k := range []string{"我不是", "不是我", "不对", "不是啊", "不是的", "你搞错了", "说错了", "别胡说"} {
		if strings.Contains(a, k) {
			return true
		}
	}
	return false
}

func isNarratorDeterministicKind(kind CommandKind) bool {
	switch kind {
	case CmdInspectInventory, CmdInspectScene, CmdExploreWorld, CmdPickup, CmdTravel:
		return true
	default:
		return false
	}
}
