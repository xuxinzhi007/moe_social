package memory

import (
	"fmt"
	"strings"
	"time"
)

const DailyNoteKeyPrefix = "daily_note:"

// DailyNoteKey 返回 OpenClaw 式日记层 key（memory/YYYY-MM-DD.md 的 KV 等价）。
func DailyNoteKey(day time.Time) string {
	return DailyNoteKeyPrefix + day.UTC().Format("2006-01-02")
}

// IsDailyNoteKey 是否为日记层（工作记忆，非精选长期事实）。
func IsDailyNoteKey(key string) bool {
	return strings.HasPrefix(strings.ToLower(strings.TrimSpace(key)), DailyNoteKeyPrefix)
}

// ParseDailyNoteDate 从 key 解析日期。
func ParseDailyNoteDate(key string) (time.Time, bool) {
	k := strings.TrimSpace(key)
	if !strings.HasPrefix(strings.ToLower(k), DailyNoteKeyPrefix) {
		return time.Time{}, false
	}
	s := strings.TrimPrefix(strings.ToLower(k), DailyNoteKeyPrefix)
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return time.Time{}, false
	}
	return t.UTC(), true
}

// ExcludeDailyNotes 排除日记项，供精选层检索。
func ExcludeDailyNotes(records []Record) []Record {
	out := make([]Record, 0, len(records))
	for _, r := range records {
		if IsDailyNoteKey(r.Key) {
			continue
		}
		out = append(out, r)
	}
	return out
}

// RecentDailyNotes 取今天与昨天日记（OpenClaw 默认加载今日+昨日）。
func RecentDailyNotes(records []Record, now time.Time) []Record {
	if now.IsZero() {
		now = time.Now().UTC()
	}
	today := now.UTC().Truncate(24 * time.Hour)
	yesterday := today.Add(-24 * time.Hour)
	want := map[string]struct{}{
		today.Format("2006-01-02"):     {},
		yesterday.Format("2006-01-02"): {},
	}
	out := make([]Record, 0, 2)
	for _, r := range records {
		if !IsDailyNoteKey(r.Key) {
			continue
		}
		if d, ok := ParseDailyNoteDate(r.Key); ok {
			if _, hit := want[d.Format("2006-01-02")]; hit {
				out = append(out, r)
			}
		}
	}
	return out
}

// MergeDailyNoteContent 追加一行观测（去重相邻空行）。
func MergeDailyNoteContent(existing, line string) string {
	line = strings.TrimSpace(line)
	if line == "" {
		return strings.TrimSpace(existing)
	}
	base := strings.TrimSpace(existing)
	if base == "" {
		return line
	}
	if strings.Contains(base, line) {
		return base
	}
	return base + "\n" + line
}

// FormatDailyNotesBlock 格式化日记注入块。
func FormatDailyNotesBlock(notes []Record, maxRunes int) string {
	if len(notes) == 0 || maxRunes <= 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("=== 近期日记（工作记忆，今日/昨日）===\n")
	used := len([]rune(b.String()))
	for _, n := range notes {
		dateLabel := strings.TrimPrefix(strings.ToLower(n.Key), DailyNoteKeyPrefix)
		chunk := fmt.Sprintf("[%s]\n%s\n", dateLabel, strings.TrimSpace(n.Value))
		runes := len([]rune(chunk))
		if used+runes > maxRunes && used > 0 {
			break
		}
		b.WriteString(chunk)
		used += runes
	}
	return strings.TrimSpace(b.String())
}
