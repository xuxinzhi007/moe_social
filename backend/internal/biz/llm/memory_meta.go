package llmbiz

import "strings"

const (
	defaultMemoryType = "fact"
	defaultSource     = "unknown"
	defaultConfidence = 0.6
)

func normalizeMemoryType(in string) string {
	v := strings.ToLower(strings.TrimSpace(in))
	if v == "" {
		return ""
	}
	switch v {
	case "preference", "profile", "plan", "relationship", "fact", "style":
		return v
	default:
		return defaultMemoryType
	}
}

func inferMemoryTypeByKey(key string) string {
	k := strings.ToLower(strings.TrimSpace(key))
	if k == "" {
		return defaultMemoryType
	}
	if strings.Contains(k, "hobby") || strings.Contains(k, "like") || strings.Contains(k, "dislike") || strings.Contains(k, "favorite") || strings.Contains(k, "preference") {
		return "preference"
	}
	if strings.Contains(k, "goal") || strings.Contains(k, "plan") || strings.Contains(k, "todo") {
		return "plan"
	}
	if strings.Contains(k, "friend") || strings.Contains(k, "family") || strings.Contains(k, "relation") {
		return "relationship"
	}
	if strings.Contains(k, "style") || strings.Contains(k, "tone") {
		return "style"
	}
	if strings.Contains(k, "profile") {
		return "profile"
	}
	return defaultMemoryType
}

func clampConfidence(in float64) float64 {
	if in <= 0 {
		return defaultConfidence
	}
	if in > 1 {
		return 1
	}
	return in
}

func normalizeSource(in string) string {
	v := strings.TrimSpace(in)
	if v == "" {
		return defaultSource
	}
	if len(v) > 128 {
		return v[:128]
	}
	return v
}

func isManualSource(source string) bool {
	v := strings.ToLower(strings.TrimSpace(source))
	return strings.HasPrefix(v, "manual")
}
