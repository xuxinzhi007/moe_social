package gamebiz

import (
	"fmt"
	"strings"
)

// StoryArc 故事线进度（P4 蝴蝶效应追踪）。
type StoryArc struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Stage int    `json:"stage"`
	Beat  string `json:"beat"`
}

func ensureStoryArcs(flags *WorldFlags) {
	if flags == nil {
		return
	}
	if len(flags.StoryArcs) > 0 {
		return
	}
	flags.StoryArcs = []StoryArc{
		{ID: "fog_mystery", Title: "雾中十三响", Stage: 0, Beat: "钟楼在晨雾中若隐若现"},
		{ID: "town_secrets", Title: "镇上的秘密", Stage: 0, Beat: "居民对陌生人保持警惕"},
	}
}

func storyArcBlock(flags WorldFlags) string {
	if len(flags.StoryArcs) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【故事线】\n")
	for _, arc := range flags.StoryArcs {
		b.WriteString(fmt.Sprintf("- %s（阶段 %d）：%s\n", arc.Title, arc.Stage, arc.Beat))
	}
	if len(flags.PendingEvents) > 0 {
		b.WriteString("【待触发蝴蝶效应】\n")
		for _, ev := range flags.PendingEvents {
			b.WriteString("- ")
			b.WriteString(ev)
			b.WriteString("\n")
		}
	}
	return b.String()
}

// advanceStoryArcs 根据回合结果推进故事线与蝴蝶效应队列。
func advanceStoryArcs(flags *WorldFlags, output turnLLMOutput, favorDeltas map[string]int) {
	if flags == nil {
		return
	}
	ensureStoryArcs(flags)
	oldPhase := flags.StoryPhase
	if v, ok := output.FlagsPatch["story_phase"].(float64); ok {
		flags.StoryPhase = int(v)
	} else if v, ok := output.FlagsPatch["story_phase"].(int); ok {
		flags.StoryPhase = v
	}
	if flags.StoryPhase > oldPhase {
		for i := range flags.StoryArcs {
			if flags.StoryArcs[i].ID == "fog_mystery" {
				flags.StoryArcs[i].Stage++
				flags.StoryArcs[i].Beat = "钟楼的秘密逐渐浮出水面"
			}
		}
		flags.PendingEvents = appendUnique(flags.PendingEvents, "午夜钟声可能提前响起")
	}
	for name, delta := range favorDeltas {
		if delta >= 3 {
			flags.PendingEvents = appendUnique(
				flags.PendingEvents,
				fmt.Sprintf("%s 对你的态度发生了明显变化", name),
			)
		}
	}
	if output.RandomEvent != nil && strings.TrimSpace(output.RandomEvent.Description) != "" {
		flags.PendingEvents = appendUnique(flags.PendingEvents, output.RandomEvent.Description)
	}
	if len(flags.PendingEvents) > 8 {
		flags.PendingEvents = flags.PendingEvents[len(flags.PendingEvents)-8:]
	}
}
