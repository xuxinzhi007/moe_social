package brain

import (
	"strings"
	"unicode"
)

// bigramSet 字符 bigram 集合，用于轻量相似度。
func bigramSet(s string) map[string]struct{} {
	r := []rune(normalizeForSim(s))
	out := make(map[string]struct{})
	if len(r) == 0 {
		return out
	}
	if len(r) == 1 {
		out[string(r)] = struct{}{}
		return out
	}
	for i := 0; i < len(r)-1; i++ {
		out[string(r[i:i+2])] = struct{}{}
	}
	return out
}

func normalizeForSim(s string) string {
	s = strings.TrimSpace(s)
	var b strings.Builder
	for _, ch := range s {
		if unicode.IsSpace(ch) {
			continue
		}
		if unicode.IsPunct(ch) {
			continue
		}
		b.WriteRune(ch)
	}
	return b.String()
}

// contentSimilarity 0~1，基于 bigram Jaccard。
func contentSimilarity(a, b string) float64 {
	a = normalizeForSim(a)
	b = normalizeForSim(b)
	if a == "" || b == "" {
		return 0
	}
	if a == b {
		return 1
	}
	if strings.Contains(a, b) || strings.Contains(b, a) {
		shorter, longer := a, b
		if len([]rune(a)) > len([]rune(b)) {
			shorter, longer = b, a
		}
		if len([]rune(longer)) > 0 {
			return float64(len([]rune(shorter))) / float64(len([]rune(longer)))
		}
	}
	sa, sb := bigramSet(a), bigramSet(b)
	if len(sa) == 0 || len(sb) == 0 {
		return 0
	}
	inter := 0
	for k := range sa {
		if _, ok := sb[k]; ok {
			inter++
		}
	}
	union := len(sa) + len(sb) - inter
	if union == 0 {
		return 0
	}
	return float64(inter) / float64(union)
}

func shouldCluster(a, b string, tagsA, tagsB []string) bool {
	sim := contentSimilarity(a, b)
	if sim >= 0.52 {
		return true
	}
	if sim >= 0.38 && tagOverlap(tagsA, tagsB) >= 2 {
		return true
	}
	return false
}

func tagOverlap(a, b []string) int {
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	set := map[string]struct{}{}
	for _, t := range a {
		set[t] = struct{}{}
	}
	n := 0
	for _, t := range b {
		if _, ok := set[t]; ok {
			n++
		}
	}
	return n
}

// mergeClusterTexts 算法合并：去重相似句，保留不同表述。
func mergeClusterTexts(lines []string) string {
	unique := make([]string, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		dup := false
		for _, u := range unique {
			if contentSimilarity(line, u) >= 0.72 {
				dup = true
				break
			}
		}
		if !dup {
			unique = append(unique, line)
		}
	}
	if len(unique) == 0 {
		return ""
	}
	if len(unique) == 1 {
		return unique[0]
	}
	return strings.Join(unique, " · ")
}
