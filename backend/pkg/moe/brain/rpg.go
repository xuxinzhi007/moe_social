package brain

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/port"

	"gorm.io/gorm"
)

const (
	// MaxLockedSkills RPG 技能槽上限。
	MaxLockedSkills = 8
	xpPerLevel      = 100
	compressedKey   = "persona_summary:compressed"
)

// RpgConfig 存于 MoeAgentRuntime.ConfigJSON.rpg。
type RpgConfig struct {
	TotalXP               int                 `json:"total_xp"`
	LockedSkills          []string            `json:"locked_skills"`
	LastDreamAt           string              `json:"last_dream_at,omitempty"`
	DreamEnabled          bool                `json:"dream_enabled"`
	DreamCron             string              `json:"dream_cron,omitempty"`
	NextDreamAt           string              `json:"next_dream_at,omitempty"`
	AutonomousMindEnabled bool                `json:"autonomous_mind_enabled"`
	LastThought           string              `json:"last_thought,omitempty"`
	LastThoughtAt         string              `json:"last_thought_at,omitempty"`
	ThoughtHistory        []string            `json:"thought_history,omitempty"`
	PendingDeletes        []PendingDeleteMark `json:"pending_deletes,omitempty"`
}

// RpgView 管理端 Memory RPG 快照。
type RpgView struct {
	AgentKey       string         `json:"agent_key"`
	Level          int            `json:"level"`
	XP             int            `json:"xp"`
	XPToNext       int            `json:"xp_to_next"`
	StabilityScore int            `json:"stability_score"`
	Skills         []RpgSkill     `json:"skills"`
	Fragments      []RpgFragment  `json:"fragments"`
	RecentDreams   []RpgDreamItem `json:"recent_dreams"`
	Stats          RpgStats       `json:"stats"`
	LastDreamAt    string         `json:"last_dream_at"`
	DreamEnabled          bool           `json:"dream_enabled"`
	DreamCron             string         `json:"dream_cron"`
	NextDreamAt           string         `json:"next_dream_at"`
	AutonomousMindEnabled bool           `json:"autonomous_mind_enabled"`
	PendingDeleteCount    int            `json:"pending_delete_count"`
}

type RpgSkill struct {
	Tag        string `json:"tag"`
	Label      string `json:"label"`
	Level      int    `json:"level"`
	Locked     bool   `json:"locked"`
	UsageCount int    `json:"usage_count"`
}

type RpgFragment struct {
	ID           uint   `json:"id"`
	Kind         string `json:"kind"`
	Title        string `json:"title"`
	Status       string `json:"status"`
	QualityScore int    `json:"quality_score"`
	Approved     bool   `json:"approved"`
	CreatedAt    string `json:"created_at"`
	MemoryKey    string `json:"memory_key"`
}

type RpgDreamItem struct {
	ID       uint   `json:"id"`
	RanAt    string `json:"ran_at"`
	Summary  string `json:"summary"`
	Refined  int    `json:"refined"`
	Merged   int    `json:"merged"`
	Archived int    `json:"archived"`
	XPGained int    `json:"xp_gained"`
}

type RpgStats struct {
	TotalFragments int `json:"total_fragments"`
	SolidMemories  int `json:"solid_memories"`
	PendingTidy    int `json:"pending_tidy"`
	LockedSkills   int `json:"locked_skills"`
	GraphNodes     int `json:"graph_nodes"`
}

// DreamResult 入梦 consolidation 结果。
type DreamResult struct {
	Summary  string `json:"summary"`
	Refined  int    `json:"refined"`
	Merged   int    `json:"merged"`
	Archived int    `json:"archived"`
	XPGained int    `json:"xp_gained"`
	Level    int    `json:"level"`
	XP       int    `json:"xp"`
}

// CompressResult 压缩记忆结果。
type CompressResult struct {
	MemoryKey       string `json:"memory_key"`
	Summary         string `json:"summary"`
	SourceCount     int    `json:"source_count"`
	XPGained        int    `json:"xp_gained"`
	SweptCount      int    `json:"swept_count"`
	MergedClusters  int    `json:"merged_clusters"`
	MarkedCount     int    `json:"marked_count"`
	PendingRemaining int   `json:"pending_remaining"`
}

// TidyResult 整理碎片结果。
type TidyResult struct {
	Total    int `json:"total"`
	Approved int `json:"approved"`
	XPGained int `json:"xp_gained"`
}

// RpgDeps Memory RPG 依赖。
type RpgDeps struct {
	DB        *gorm.DB
	RPC       port.MoeToolPort
	Inference RefineDeps
}

func levelFromXP(totalXP int) (level, ringXP, xpToNext int) {
	if totalXP < 0 {
		totalXP = 0
	}
	level = 1 + totalXP/xpPerLevel
	ringXP = totalXP % xpPerLevel
	xpToNext = xpPerLevel - ringXP
	if xpToNext == xpPerLevel {
		xpToNext = xpPerLevel
	}
	return level, ringXP, xpToNext
}

// LockedSkillsFromRuntime 读取 RPG 锁定技能 tag。
func LockedSkillsFromRuntime(rt model.MoeAgentRuntime) []string {
	cfg := parseRpgConfig(rt.ConfigJSON)
	return cfg.LockedSkills
}

func parseRpgConfig(raw string) RpgConfig {
	raw = strings.TrimSpace(raw)
	if raw == "" || !strings.HasPrefix(raw, "{") {
		return RpgConfig{LockedSkills: []string{}}
	}
	var root struct {
		Rpg RpgConfig `json:"rpg"`
	}
	if json.Unmarshal([]byte(raw), &root) != nil {
		return RpgConfig{LockedSkills: []string{}}
	}
	out := root.Rpg
	if out.LockedSkills == nil {
		out.LockedSkills = []string{}
	}
	if out.PendingDeletes == nil {
		out.PendingDeletes = []PendingDeleteMark{}
	}
	return out
}

func mergeRpgConfig(configJSON string, cfg RpgConfig) (string, error) {
	root := map[string]any{}
	raw := strings.TrimSpace(configJSON)
	if raw != "" && strings.HasPrefix(raw, "{") {
		_ = json.Unmarshal([]byte(raw), &root)
	}
	root["rpg"] = cfg
	b, err := json.Marshal(root)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func saveRpgConfig(db *gorm.DB, agentKey string, cfg RpgConfig) error {
	var rt model.MoeAgentRuntime
	if err := db.Where("agent_key = ?", agentKey).First(&rt).Error; err != nil {
		return err
	}
	merged, err := mergeRpgConfig(rt.ConfigJSON, cfg)
	if err != nil {
		return err
	}
	return db.Model(&model.MoeAgentRuntime{}).Where("agent_key = ?", agentKey).Update("config_json", merged).Error
}

func addXP(db *gorm.DB, agentKey string, delta int) (RpgConfig, error) {
	cfg := loadRpgConfig(db, agentKey)
	cfg.TotalXP += delta
	if cfg.TotalXP < 0 {
		cfg.TotalXP = 0
	}
	if err := saveRpgConfig(db, agentKey, cfg); err != nil {
		return RpgConfig{}, err
	}
	return cfg, nil
}

func loadRpgConfig(db *gorm.DB, agentKey string) RpgConfig {
	var rt model.MoeAgentRuntime
	if err := db.Where("agent_key = ?", agentKey).First(&rt).Error; err != nil {
		return RpgConfig{LockedSkills: []string{}}
	}
	return parseRpgConfig(rt.ConfigJSON)
}

func fragmentStatus(approved bool, quality int) string {
	if approved && quality >= QualityApproveThreshold {
		return "solid"
	}
	if quality >= 50 {
		return "fragment"
	}
	return "cracked"
}

func skillLabel(tag string) string {
	tag = strings.TrimSpace(tag)
	if i := strings.Index(tag, ":"); i >= 0 && i < len(tag)-1 {
		return tag[i+1:]
	}
	return tag
}

func skillLevel(count int) int {
	lv := 1 + count/5
	if lv > 5 {
		return 5
	}
	if lv < 1 {
		return 1
	}
	return lv
}

func lockedSet(tags []string) map[string]bool {
	out := make(map[string]bool, len(tags))
	for _, t := range tags {
		t = strings.TrimSpace(t)
		if t != "" {
			out[t] = true
		}
	}
	return out
}

// LoadRpgView 加载 Memory RPG 快照。
func LoadRpgView(ctx context.Context, deps RpgDeps, agentKey string) (RpgView, error) {
	out := RpgView{AgentKey: strings.TrimSpace(agentKey)}
	if deps.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	snap, err := LoadSnapshot(ctx, deps.DB, deps.RPC, agentKey)
	if err != nil {
		return out, err
	}
	cfg := loadRpgConfig(deps.DB, agentKey)
	level, ringXP, xpToNext := levelFromXP(cfg.TotalXP)
	out.Level = level
	out.XP = ringXP
	out.XPToNext = xpToNext
	out.StabilityScore = snap.StabilityScore
	out.LastDreamAt = cfg.LastDreamAt
	out.DreamEnabled = cfg.DreamEnabled
	out.DreamCron = cfg.DreamCron
	if out.DreamCron == "" {
		out.DreamCron = defaultDreamCron
	}
	out.NextDreamAt = cfg.NextDreamAt
	out.AutonomousMindEnabled = cfg.AutonomousMindEnabled
	out.PendingDeleteCount = len(cfg.PendingDeletes)

	locked := lockedSet(cfg.LockedSkills)
	skills := make([]RpgSkill, 0, len(snap.TagStats))
	for _, st := range snap.TagStats {
		if st.Tag == "" {
			continue
		}
		skills = append(skills, RpgSkill{
			Tag:        st.Tag,
			Label:      skillLabel(st.Tag),
			Level:      skillLevel(st.Count),
			Locked:     locked[st.Tag],
			UsageCount: st.Count,
		})
	}
	sort.Slice(skills, func(i, j int) bool {
		if skills[i].UsageCount == skills[j].UsageCount {
			return skills[i].Tag < skills[j].Tag
		}
		return skills[i].UsageCount > skills[j].UsageCount
	})
	out.Skills = skills

	fragments := make([]RpgFragment, 0, len(snap.Episodes)+len(snap.Memories))
	var solid, pending int
	for _, ep := range snap.Episodes {
		st := fragmentStatus(ep.Approved, ep.QualityScore)
		if st == "solid" {
			solid++
		} else {
			pending++
		}
		title := clipSummary(ep.Content, 48)
		if title == "" {
			title = fmt.Sprintf("自传 #%d", ep.ID)
		}
		fragments = append(fragments, RpgFragment{
			ID:           ep.ID,
			Kind:         "episode",
			Title:        title,
			Status:       st,
			QualityScore: ep.QualityScore,
			Approved:     ep.Approved,
			CreatedAt:    ep.CreatedAt,
			MemoryKey:    ep.MemoryKey,
		})
	}
	for _, mem := range snap.Memories {
		st := "solid"
		if strings.HasPrefix(mem.Key, "archived:") {
			st = "archived"
		}
		title := clipSummary(mem.Value, 48)
		if title == "" {
			title = mem.Key
		}
		if st == "solid" {
			solid++
		}
		fragments = append(fragments, RpgFragment{
			Kind:      "memory",
			Title:     title,
			Status:    st,
			MemoryKey: mem.Key,
			CreatedAt: mem.UpdatedAt,
		})
	}
	out.Fragments = fragments

	var dreamRows []model.MoeBrainDreamLog
	_ = deps.DB.Where("agent_key = ?", agentKey).Order("created_at desc").Limit(8).Find(&dreamRows).Error
	for _, d := range dreamRows {
		out.RecentDreams = append(out.RecentDreams, RpgDreamItem{
			ID:       d.ID,
			RanAt:    d.CreatedAt.Format("2006-01-02 15:04:05"),
			Summary:  d.Summary,
			Refined:  d.Refined,
			Merged:   d.Merged,
			Archived: d.Archived,
			XPGained: d.XPGained,
		})
	}

	graph := BuildGraphView(snap, nil, 80)
	out.Stats = RpgStats{
		TotalFragments: len(fragments),
		SolidMemories:  solid,
		PendingTidy:    pending,
		LockedSkills:   len(cfg.LockedSkills),
		GraphNodes:     len(graph.Nodes),
	}
	return out, nil
}

// RunDream 入梦 consolidation：可选润色 + 写 dream log + 奖励 XP。
func RunDream(ctx context.Context, deps RpgDeps, agentKey string, skipCurate bool) (DreamResult, error) {
	out := DreamResult{}
	agentKey = strings.TrimSpace(agentKey)
	if deps.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	setDreaming(agentKey, true)
	defer setDreaming(agentKey, false)

	refined := 0
	if !skipCurate && deps.Inference.DB != nil && deps.Inference.Inference.Ready() {
		results, err := CurateLowQuality(ctx, deps.Inference, agentKey, CurateOptions{
			MaxEpisodes:           5,
			MaxAttemptsPerEpisode: 3,
			MinQuality:            QualityApproveThreshold,
			Force:                 false,
		})
		if err == nil {
			for _, r := range results {
				if r.Approved {
					refined++
				}
			}
		}
	}

	snap, err := LoadSnapshot(ctx, deps.DB, deps.RPC, agentKey)
	if err != nil {
		return out, err
	}
	merged := 0
	if len(snap.TagStats) > 0 {
		merged = 1
	}
	archived := countCracked(snap.Episodes)

	xp := refined*15 + merged*10
	summary := buildDreamSummary(snap, refined, merged, archived)
	facts := summary
	if deps.Inference.Inference.Ready() {
		if narrative, err := narrateDreamLLM(ctx, deps.Inference.Inference, snap.DisplayName, facts); err == nil && narrative != "" {
			summary = narrative
		}
	}

	row := model.MoeBrainDreamLog{
		AgentKey: agentKey,
		Summary:  summary,
		Refined:  refined,
		Merged:   merged,
		Archived: archived,
		XPGained: xp,
	}
	if err := deps.DB.Create(&row).Error; err != nil {
		return out, err
	}

	cfg := loadRpgConfig(deps.DB, agentKey)
	cfg.TotalXP += xp
	cfg.LastDreamAt = time.Now().Format("2006-01-02 15:04:05")
	if err := saveRpgConfig(deps.DB, agentKey, cfg); err != nil {
		return out, err
	}

	level, ringXP, _ := levelFromXP(cfg.TotalXP)
	out.Summary = summary
	out.Refined = refined
	out.Merged = merged
	out.Archived = archived
	out.XPGained = xp
	out.Level = level
	out.XP = ringXP
	return out, nil
}

func countCracked(episodes []EpisodeItem) int {
	n := 0
	for _, ep := range episodes {
		if fragmentStatus(ep.Approved, ep.QualityScore) == "cracked" {
			n++
		}
	}
	return n
}

func buildDreamSummary(snap *Snapshot, refined, merged, archived int) string {
	if snap == nil {
		return "入梦完成：暂无自传数据"
	}
	topTag := ""
	if len(snap.TagStats) > 0 {
		topTag = snap.TagStats[0].Tag
	}
	parts := []string{
		fmt.Sprintf("Bot「%s」入梦整理", snap.DisplayName),
		fmt.Sprintf("自传 %d 条", len(snap.Episodes)),
	}
	if refined > 0 {
		parts = append(parts, fmt.Sprintf("润色认可 %d 条", refined))
	}
	if merged > 0 && topTag != "" {
		parts = append(parts, fmt.Sprintf("主导标签 %s", topTag))
	}
	if archived > 0 {
		parts = append(parts, fmt.Sprintf("待修复碎片 %d 条", archived))
	}
	return strings.Join(parts, " · ")
}

// CompressMemories 标记-清扫式压缩：删上轮 pending → 聚类合并 → 标记待删。
func CompressMemories(ctx context.Context, deps RpgDeps, agentKey string, days int) (CompressResult, error) {
	out := CompressResult{MemoryKey: compressedKey}
	agentKey = strings.TrimSpace(agentKey)
	SetRpgWork(agentKey, "compressing")
	defer SetRpgWork(agentKey, "")
	if deps.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	if days <= 0 {
		days = 14
	}
	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ?", agentKey).First(&rt).Error; err != nil {
		return out, err
	}
	cfg := loadRpgConfig(deps.DB, agentKey)
	cutoff := time.Now().AddDate(0, 0, -days)
	forbidden := ParseTagList(rt.ForbiddenTags)

	var episodes []model.MoeBotEpisode
	if err := deps.DB.Where("agent_key = ? AND created_at >= ?", agentKey, cutoff).
		Order("created_at desc").Limit(40).Find(&episodes).Error; err != nil {
		return out, err
	}

	candidates := make([]compressCandidate, 0, len(episodes))
	for _, ep := range episodes {
		q := EffectiveQuality(ep, forbidden)
		approved := ep.Approved
		if !approved {
			approved = IsApprovedQuality(q) && !NeedsRefinement(q, parseTagsJSON(ep.TagsJSON), forbidden)
		}
		text := strings.TrimSpace(ep.Content)
		if text == "" {
			continue
		}
		candidates = append(candidates, compressCandidate{
			EpisodeID: ep.ID,
			MemoryKey: ep.MemoryKey,
			Content:   text,
			Tags:      parseTagsJSON(ep.TagsJSON),
		})
	}

	summary, swept, merged, marked, newPending, err := compressMarkSweep(ctx, deps, rt, cfg, candidates)
	out.SweptCount = swept
	out.MergedClusters = merged
	out.MarkedCount = marked
	if err != nil && swept == 0 && merged == 0 {
		return out, err
	}
	if summary == "" && err == nil {
		return out, fmt.Errorf("压缩未产生合并结果")
	}

	cfg.PendingDeletes = append(cfg.PendingDeletes, newPending...)
	out.PendingRemaining = len(cfg.PendingDeletes)
	if summary != "" {
		out.Summary = summary
		out.SourceCount = marked
		xp := 15 + merged*8 + swept*3
		if _, xerr := addXP(deps.DB, agentKey, xp); xerr != nil {
			return out, xerr
		}
		out.XPGained = xp
	}
	if err := saveRpgConfig(deps.DB, agentKey, cfg); err != nil {
		return out, err
	}
	return out, nil
}

// TidyFragments 整理低分碎片（Curate 包装 + XP）。
func TidyFragments(ctx context.Context, deps RpgDeps, agentKey string, maxEpisodes int) (TidyResult, error) {
	out := TidyResult{}
	agentKey = strings.TrimSpace(agentKey)
	SetRpgWork(agentKey, "tidying")
	defer SetRpgWork(agentKey, "")
	if maxEpisodes <= 0 {
		maxEpisodes = 10
	}
	if deps.Inference.DB == nil {
		return out, fmt.Errorf("brain: db nil")
	}
	results, err := CurateLowQuality(ctx, deps.Inference, agentKey, CurateOptions{
		MaxEpisodes:           maxEpisodes,
		MaxAttemptsPerEpisode: 3,
		MinQuality:            QualityApproveThreshold,
		Force:                 false,
	})
	if err != nil {
		return out, err
	}
	out.Total = len(results)
	for _, r := range results {
		if r.Approved {
			out.Approved++
		}
	}
	out.XPGained = out.Approved * 10
	if out.XPGained > 0 {
		if _, err := addXP(deps.DB, agentKey, out.XPGained); err != nil {
			return out, err
		}
	}
	return out, nil
}

// LockSkill 锁定或解锁 tag 技能（最多 8 个）。
func LockSkill(db *gorm.DB, agentKey, tag string, lock bool) ([]string, error) {
	tag = strings.TrimSpace(tag)
	if tag == "" {
		return nil, fmt.Errorf("tag 不能为空")
	}
	cfg := loadRpgConfig(db, agentKey)
	locked := cfg.LockedSkills
	if lock {
		if lockedSet(locked)[tag] {
			return locked, nil
		}
		if len(locked) >= MaxLockedSkills {
			return nil, fmt.Errorf("技能槽已满（最多 %d 个）", MaxLockedSkills)
		}
		locked = append(locked, tag)
	} else {
		next := make([]string, 0, len(locked))
		for _, t := range locked {
			if t != tag {
				next = append(next, t)
			}
		}
		locked = next
	}
	cfg.LockedSkills = locked
	if err := saveRpgConfig(db, agentKey, cfg); err != nil {
		return nil, err
	}
	return locked, nil
}

// ForgetMemory 删除 bot 记忆 key（已废弃）。
func ForgetMemory(ctx context.Context, deps RpgDeps, agentKey, memoryKey string) (bool, error) {
	return false, fmt.Errorf("记忆功能已移除")
}
