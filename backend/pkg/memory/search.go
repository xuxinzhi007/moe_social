package memory

import (
	"regexp"
	"strings"
	"time"
)

var searchNoiseRe = regexp.MustCompile(`[^\w\s\p{Han}]`)

type ranked struct {
	rec   Record
	score float64
}

// SearchFacing 对用户可见记忆做关键词 + 新近度排序（L1 检索 SSOT，与 LLM tools 无关）。
func SearchFacing(records []Record, query string, limit int) SearchResult {
	q := strings.TrimSpace(query)
	if limit <= 0 {
		limit = 8
	}
	if limit > 20 {
		limit = 20
	}

	candidates := FacingRecords(records)
	tokens := extractQueryTokens(q)
	rankedList := make([]ranked, 0, len(candidates))

	for _, rec := range candidates {
		norm := normalizeSearchText(rec.Key + " " + rec.Value)
		if norm == "" {
			continue
		}
		var score float64
		for _, tok := range tokens {
			if strings.Contains(norm, tok) {
				score += 2
			}
		}
		if !rec.UpdatedAt.IsZero() {
			ageDays := int(time.Since(rec.UpdatedAt).Hours() / 24)
			if ageDays < 0 {
				ageDays = 0
			}
			if ageDays > 30 {
				ageDays = 30
			}
			score += float64(30-ageDays) / 30.0
		}
		rankedList = append(rankedList, ranked{rec: rec, score: score})
	}

	sortRankedDesc(rankedList)

	selected := make([]Record, 0, limit)
	if len(tokens) > 0 {
		for _, r := range rankedList {
			if r.score < 2 {
				continue
			}
			selected = append(selected, r.rec)
			if len(selected) >= limit {
				break
			}
		}
	}
	if len(selected) == 0 && len(candidates) > 0 {
		sortByUpdatedDesc(candidates)
		for i := 0; i < len(candidates) && i < limit; i++ {
			selected = append(selected, candidates[i])
		}
	}

	items := make([]DisplayItem, 0, len(selected))
	for _, rec := range selected {
		mType := strings.TrimSpace(rec.MemoryType)
		if mType == "" {
			mType = "fact"
		}
		updated := ""
		if !rec.UpdatedAt.IsZero() {
			updated = rec.UpdatedAt.Format(time.RFC3339)
		}
		items = append(items, DisplayItem{
			ID:        rec.ID,
			Key:       strings.TrimSpace(rec.Key),
			Title:     TitleFromKey(rec.Key),
			Content:   strings.TrimSpace(rec.Value),
			Category:  CategoryLabel(mType, rec.Key),
			UpdatedAt: updated,
		})
	}

	return SearchResult{
		Query: q,
		Items: items,
		Total: len(items),
	}
}

func sortRankedDesc(list []ranked) {
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].score > list[i].score {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
}

func sortByUpdatedDesc(list []Record) {
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].UpdatedAt.After(list[i].UpdatedAt) {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
}

func extractQueryTokens(query string) []string {
	q := normalizeSearchText(query)
	if q == "" {
		return nil
	}
	parts := strings.Fields(q)
	out := make([]string, 0, len(parts))
	seen := make(map[string]struct{})
	for _, p := range parts {
		if len([]rune(p)) < 2 {
			continue
		}
		if _, ok := seen[p]; ok {
			continue
		}
		seen[p] = struct{}{}
		out = append(out, p)
	}
	return out
}

func normalizeSearchText(value string) string {
	s := strings.ToLower(strings.TrimSpace(value))
	s = searchNoiseRe.ReplaceAllString(s, " ")
	s = strings.Join(strings.Fields(s), " ")
	return strings.TrimSpace(s)
}
