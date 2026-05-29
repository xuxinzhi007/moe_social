package brain

import (
	"context"
	"fmt"
	"strings"

	"backend/model"
)

// LivePipelineStatus 由 biz 层从 runtime.LiveRuns 注入，避免 brain↔runtime 循环依赖。
type LivePipelineStatus struct {
	Running   bool
	StepLabel string
}

// PresenceView Bot 在场状态（游戏化 UI）。
type PresenceView struct {
	AgentKey        string `json:"agent_key"`
	DisplayName     string `json:"display_name"`
	Activity        string `json:"activity"`
	Mood            string `json:"mood"`
	Thought         string `json:"thought"`
	PipelineStep    string `json:"pipeline_step"`
	PipelineRunning bool   `json:"pipeline_running"`
	DreamEnabled    bool   `json:"dream_enabled"`
	DreamCron       string `json:"dream_cron"`
	NextDreamAt             string `json:"next_dream_at"`
	Dreaming                bool   `json:"dreaming"`
	AutonomousMindEnabled   bool   `json:"autonomous_mind_enabled"`
	ThoughtSource           string `json:"thought_source"`
}

// BuildPresence 根据流水线、RPG 与自传快照合成 Bot 当前想法与动作。
func BuildPresence(ctx context.Context, deps RpgDeps, agentKey string, live LivePipelineStatus) (PresenceView, error) {
	out := PresenceView{AgentKey: strings.TrimSpace(agentKey), Activity: "idle", Mood: "calm"}
	if deps.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ?", out.AgentKey).First(&rt).Error; err != nil {
		return out, err
	}
	out.DisplayName = rt.DisplayName
	cfg := loadRpgConfig(deps.DB, out.AgentKey)
	out.DreamEnabled = cfg.DreamEnabled
	out.DreamCron = cfg.DreamCron
	if out.DreamCron == "" {
		out.DreamCron = defaultDreamCron
	}
	out.NextDreamAt = cfg.NextDreamAt
	out.AutonomousMindEnabled = cfg.AutonomousMindEnabled
	out.Dreaming = IsDreaming(out.AgentKey)

	if work := CurrentRpgWork(out.AgentKey); work != "" {
		out.Activity = work
		out.Mood = "focused"
		switch work {
		case "compressing":
			out.Thought = "在记忆神社里合并重复碎片…"
		case "tidying":
			out.Thought = "把背包里的碎片一条条理顺…"
		default:
			out.Thought = "在记忆神社里整理…"
		}
		out.ThoughtSource = "rule"
		return out, nil
	}

	if out.Dreaming {
		out.Activity = "dreaming"
		out.Mood = "sleepy"
		out.Thought = "正在入梦整理记忆碎片…"
		out.ThoughtSource = "rule"
		return out, nil
	}

	if live.Running {
		out.PipelineRunning = true
		out.Activity = "posting"
		out.Mood = "focused"
		out.PipelineStep = strings.TrimSpace(live.StepLabel)
		if out.PipelineStep != "" {
			out.Thought = "试跑中：" + out.PipelineStep
		} else {
			out.Thought = "正在走发帖流水线…"
		}
		out.ThoughtSource = "rule"
		return out, nil
	}

	snap, err := LoadSnapshot(ctx, deps.DB, deps.RPC, out.AgentKey)
	if err != nil {
		fallback := idleThought(cfg, nil)
		out.Thought, out.ThoughtSource = thoughtForPresence(cfg, fallback)
		out.Activity = "exploring"
		return out, nil
	}

	pending := 0
	for _, ep := range snap.Episodes {
		if fragmentStatus(ep.Approved, ep.QualityScore) != "solid" {
			pending++
		}
	}
	out.Activity = "exploring"
	if pending >= 3 {
		out.Mood = "calm"
		fallback := fmt.Sprintf("记忆神社那边好像有点吵…还有 %d 条没理顺", pending)
		out.Thought, out.ThoughtSource = thoughtForPresence(cfg, fallback)
		return out, nil
	}
	if len(cfg.LockedSkills) > 0 {
		out.Mood = "happy"
		fallback := fmt.Sprintf("锁定了 %d 个技能，下次发帖会带上 %s", len(cfg.LockedSkills), skillLabel(cfg.LockedSkills[0]))
		out.Thought, out.ThoughtSource = thoughtForPresence(cfg, fallback)
		return out, nil
	}
	fallback := idleThought(cfg, snap)
	out.Thought, out.ThoughtSource = thoughtForPresence(cfg, fallback)
	return out, nil
}

func idleThought(cfg RpgConfig, snap *Snapshot) string {
	if snap != nil && len(snap.TagStats) > 0 {
		top := snap.TagStats[0]
		return fmt.Sprintf("最近在琢磨「%s」…", skillLabel(top.Tag))
	}
	if cfg.LastDreamAt != "" {
		return "上次入梦后记忆稳定，随便逛逛。"
	}
	return "空闲中，等下一次试跑或入梦。"
}
