package memory

import (
	"sort"
	"strings"
)

const (
	maxProfileTypes = 20
)

// BuildProfiles 按 memory_type 聚合画像摘要（纯函数，无 DB）。
func BuildProfiles(records []Record) []ProfileSummary {
	type aggItem struct {
		count      int
		confidence float64
		values     []string
		seen       map[string]struct{}
	}
	grouped := map[string]*aggItem{}

	for _, r := range FacingRecords(records) {
		mType := strings.TrimSpace(r.MemoryType)
		if mType == "" {
			mType = "general"
		}
		item, ok := grouped[mType]
		if !ok {
			item = &aggItem{seen: map[string]struct{}{}}
			grouped[mType] = item
		}
		item.count++
		item.confidence += r.Confidence
		v := strings.TrimSpace(r.Value)
		if v == "" {
			continue
		}
		if _, exists := item.seen[v]; exists {
			continue
		}
		item.seen[v] = struct{}{}
		if len(item.values) < 3 {
			item.values = append(item.values, v)
		}
	}

	type row struct {
		mType      string
		summary    string
		count      int
		confidence float64
	}
	rows := make([]row, 0, len(grouped))
	for mType, item := range grouped {
		if item.count == 0 || len(item.values) == 0 {
			continue
		}
		rows = append(rows, row{
			mType:      mType,
			summary:    strings.Join(item.values, "；"),
			count:      item.count,
			confidence: item.confidence / float64(item.count),
		})
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].count == rows[j].count {
			return rows[i].confidence > rows[j].confidence
		}
		return rows[i].count > rows[j].count
	})
	if len(rows) > maxProfileTypes {
		rows = rows[:maxProfileTypes]
	}

	out := make([]ProfileSummary, 0, len(rows))
	for _, r := range rows {
		conf := r.confidence
		if conf < 0 {
			conf = 0
		}
		if conf > 1 {
			conf = 1
		}
		out = append(out, ProfileSummary{
			MemoryType: r.mType,
			Summary:    r.summary,
			ItemCount:  r.count,
			Confidence: conf,
		})
	}
	return out
}
