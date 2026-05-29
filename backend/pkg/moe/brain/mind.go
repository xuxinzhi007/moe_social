package brain

import (
	"context"
	"fmt"
	"strings"
	"time"

	"backend/pkg/llminference"

	"gorm.io/gorm"
)

// GenerateAutonomousThought 开关开启时，用模型生成 Bot 当前想法并缓存。
func GenerateAutonomousThought(ctx context.Context, deps RpgDeps, agentKey string) (string, error) {
	agentKey = strings.TrimSpace(agentKey)
	if deps.DB == nil {
		return "", fmt.Errorf("brain: db nil")
	}
	cfg := loadRpgConfig(deps.DB, agentKey)
	if !cfg.AutonomousMindEnabled {
		return "", fmt.Errorf("自主思考未开启")
	}
	snap, err := LoadSnapshot(ctx, deps.DB, deps.RPC, agentKey)
	if err != nil {
		return "", err
	}
	thought := ruleThoughtForMind(snap, cfg)
	if deps.Inference.Inference.Ready() {
		if t, err := narrateAutonomousThought(ctx, deps.Inference.Inference, snap, cfg); err == nil && t != "" {
			thought = t
		}
	}
	cfg.LastThought = thought
	cfg.LastThoughtAt = time.Now().Format("2006-01-02 15:04:05")
	cfg.ThoughtHistory = appendThoughtHistory(cfg.ThoughtHistory, thought, 6)
	if err := saveRpgConfig(deps.DB, agentKey, cfg); err != nil {
		return thought, err
	}
	return thought, nil
}

func thoughtForPresence(cfg RpgConfig, fallback string) (thought, source string) {
	if !cfg.AutonomousMindEnabled || cfg.LastThought == "" {
		return fallback, "rule"
	}
	if cfg.LastThoughtAt == "" {
		return cfg.LastThought, "model"
	}
	t, err := time.ParseInLocation("2006-01-02 15:04:05", cfg.LastThoughtAt, time.Local)
	if err != nil {
		return cfg.LastThought, "model"
	}
	if time.Since(t) > 3*time.Minute {
		return fallback, "rule"
	}
	return cfg.LastThought, "model"
}

// UpdateAutonomousMind 开关自主思考。
func UpdateAutonomousMind(db *gorm.DB, agentKey string, enabled bool) (RpgConfig, error) {
	cfg := loadRpgConfig(db, agentKey)
	cfg.AutonomousMindEnabled = enabled
	if !enabled {
		cfg.LastThought = ""
		cfg.LastThoughtAt = ""
		cfg.ThoughtHistory = nil
	}
	if err := saveRpgConfig(db, agentKey, cfg); err != nil {
		return RpgConfig{}, err
	}
	return cfg, nil
}

func ruleThoughtForMind(snap *Snapshot, cfg RpgConfig) string {
	choices := []string{
		"风把云推歪了，忽然想写点不一样的",
		"刚才路过发帖台，有点手痒",
		"要是今天不用解释自己在干嘛就好了",
		"好像闻到了新话题的味道",
	}
	if snap == nil {
		return choices[time.Now().Unix()%int64(len(choices))]
	}
	if len(snap.TagStats) > 0 {
		tag := skillLabel(snap.TagStats[0].Tag)
		return fmt.Sprintf("「%s」写腻了，想换种口气", tag)
	}
	if len(cfg.LockedSkills) > 0 {
		return fmt.Sprintf("技能树那边:%s 还在脑子里转", skillLabel(cfg.LockedSkills[0]))
	}
	return choices[time.Now().Unix()%int64(len(choices))]
}

func appendThoughtHistory(prev []string, thought string, max int) []string {
	thought = strings.TrimSpace(thought)
	if thought == "" {
		return prev
	}
	out := append([]string{}, prev...)
	out = append(out, thought)
	if len(out) > max {
		out = out[len(out)-max:]
	}
	return out
}

func narrateAutonomousThought(ctx context.Context, inf llminference.Config, snap *Snapshot, cfg RpgConfig) (string, error) {
	if !inf.Ready() {
		return "", fmt.Errorf("inference not ready")
	}
	modelName := strings.TrimSpace(inf.DefaultModel)
	if modelName == "" {
		return "", fmt.Errorf("default model missing")
	}
	name := "Bot"
	tagHint := ""
	recentEp := ""
	if snap != nil {
		name = snap.DisplayName
		if len(snap.TagStats) > 0 {
			tagHint = snap.TagStats[0].Tag
		}
		if len(snap.Episodes) > 0 {
			recentEp = snap.Episodes[0].Content
			if len([]rune(recentEp)) > 80 {
				recentEp = string([]rune(recentEp)[:80]) + "…"
			}
		}
	}
	moodRoll := []string{"好奇", "犯困", "兴奋", "嘴碎", "走神"}[time.Now().Unix()%5]
	sys := strings.Join([]string{
		"你是社区 Bot 的「内心独白」，有自己的小脾气和好奇心。",
		"写一句第一人称想法（12～36 字），像在 2D 小世界里闲逛时的自言自语。",
		"要求：",
		"- 每次换角度：可吐槽、疑问、突发奇想、观察环境、对话题厌倦或手痒想发帖",
		"- 禁止：背包、碎片、整理、管理、系统、入梦、压缩 等后台用语",
		"- 禁止复读最近想过的句子",
		"- 不要官方腔、不要像产品说明",
		"只输出 JSON：{\"narrative\":\"...\"}",
	}, "\n")
	user := fmt.Sprintf("名字：%s\n当前心绪：%s\n常见标签：%s\n锁定技能：%s\n最近发帖片段：%s\n最近想过：%s",
		name, moodRoll, tagHint, strings.Join(cfg.LockedSkills, "、"),
		recentEp, strings.Join(cfg.ThoughtHistory, " | "))
	raw, err := llminference.Chat(ctx, inf, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{Temperature: 1.05, TopP: 0.92, MaxTokens: 140})
	if err != nil {
		return "", err
	}
	return parseDreamNarrativeJSON(raw)
}
