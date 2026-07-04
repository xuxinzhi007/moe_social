package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"backend/model"
)

// StoryArc 故事线进度（P4 蝴蝶效应追踪）。
type StoryArc struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Stage int    `json:"stage"`
	Beat  string `json:"beat"`
}

// StoryArcConfig DB 故事线配置的阶段触发器。
type StageTrigger struct {
	MinPhase     int    `json:"min_phase"`
	Beat         string `json:"beat"`
	Butterfly    string `json:"butterfly,omitempty"`
}

// StageNarrative DB 故事线配置的阶段叙事。
type StageNarrative struct {
	Stage       int    `json:"stage"`
	Narrative   string `json:"narrative"`
}

// loadStoryArcsFromDB 从 DB 加载活跃故事线配置，失败时返回 nil。
func loadStoryArcsFromDB(ctx context.Context, st Store) []model.GameStoryArc {
	if st == nil {
		return nil
	}
	dbCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()
	arcs, err := st.ListActiveStoryArcs(dbCtx)
	if err != nil {
		slog.Warn("[story_arc] 加载 DB 故事线失败，回退硬编码", "err", err)
		return nil
	}
	return arcs
}

// defaultStoryArcs 硬编码的默认故事线。
func defaultStoryArcs() []StoryArc {
	return []StoryArc{
		{ID: "fog_mystery", Title: "雾中十三响", Stage: 0, Beat: "钟楼在晨雾中若隐若现"},
		{ID: "town_secrets", Title: "镇上的秘密", Stage: 0, Beat: "居民对陌生人保持警惕"},
	}
}

func ensureStoryArcs(flags *WorldFlags) {
	ensureStoryArcsWithDB(context.Background(), nil, flags)
}

func ensureStoryArcsWithDB(ctx context.Context, st Store, flags *WorldFlags) {
	if flags == nil {
		return
	}
	if len(flags.StoryArcs) > 0 {
		return
	}
	// 优先从 DB 加载
	if dbArcs := loadStoryArcsFromDB(ctx, st); len(dbArcs) > 0 {
		for _, arc := range dbArcs {
			beat := ""
			// 解析 StageTriggersJSON 获取初始 beat
			var triggers []StageTrigger
			if err := json.Unmarshal([]byte(arc.StageTriggersJSON), &triggers); err == nil && len(triggers) > 0 {
				beat = triggers[0].Beat
			}
			flags.StoryArcs = append(flags.StoryArcs, StoryArc{
				ID:    arc.ArcKey,
				Title: arc.Title,
				Stage: 0,
				Beat:  beat,
			})
		}
		return
	}
	// 回退硬编码
	flags.StoryArcs = defaultStoryArcs()
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
	advanceStoryArcsWithDB(context.Background(), nil, flags, output, favorDeltas)
}

// advanceStoryArcsWithDB 从 DB 读取故事线配置来推进。
func advanceStoryArcsWithDB(ctx context.Context, st Store, flags *WorldFlags, output turnLLMOutput, favorDeltas map[string]int) {
	if flags == nil {
		return
	}
	ensureStoryArcsWithDB(ctx, st, flags)
	oldPhase := flags.StoryPhase
	if v, ok := output.FlagsPatch["story_phase"].(float64); ok {
		flags.StoryPhase = int(v)
	} else if v, ok := output.FlagsPatch["story_phase"].(int); ok {
		flags.StoryPhase = v
	}

	// 尝试从 DB 加载故事线配置
	dbArcs := loadStoryArcsFromDB(ctx, st)
	dbArcMap := map[string]model.GameStoryArc{}
	for _, da := range dbArcs {
		dbArcMap[da.ArcKey] = da
	}

	if flags.StoryPhase > oldPhase {
		for i := range flags.StoryArcs {
			arc := &flags.StoryArcs[i]
			arc.Stage++
			// 优先从 DB 配置获取新 beat
			if dbArc, ok := dbArcMap[arc.ID]; ok {
				beat, butterfly := resolveStageFromDB(dbArc, arc.Stage, flags.StoryPhase)
				if beat != "" {
					arc.Beat = beat
				}
				if butterfly != "" {
					flags.PendingEvents = appendUnique(flags.PendingEvents, butterfly)
				}
			} else {
				// 回退硬编码逻辑
				if arc.ID == "fog_mystery" {
					arc.Beat = "钟楼的秘密逐渐浮出水面"
				}
				flags.PendingEvents = appendUnique(flags.PendingEvents, "午夜钟声可能提前响起")
			}
		}
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

// resolveStageFromDB 从 DB 故事线配置中解析当前阶段的 beat 和蝴蝶效应。
func resolveStageFromDB(dbArc model.GameStoryArc, stage, phase int) (beat, butterfly string) {
	var triggers []StageTrigger
	if err := json.Unmarshal([]byte(dbArc.StageTriggersJSON), &triggers); err != nil {
		return "", ""
	}
	for _, t := range triggers {
		if phase >= t.MinPhase {
			beat = t.Beat
			butterfly = t.Butterfly
		}
	}
	return beat, butterfly
}
