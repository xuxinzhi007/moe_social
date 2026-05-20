package memory

import (
	"fmt"
	"strings"
)

// BootstrapBudget OpenClaw 式注入预算：精选层优先，其次日记，再检索命中。
type BootstrapBudget struct {
	MaxProfileRunes int
	MaxDailyRunes   int
	MaxSearchItems  int
	MaxSearchRunes  int
}

// DefaultBootstrapBudget 默认预算（约等于 MEMORY.md + 2 日日记 + search Top-K）。
func DefaultBootstrapBudget() BootstrapBudget {
	return BootstrapBudget{
		MaxProfileRunes: 280,
		MaxDailyRunes:   400,
		MaxSearchItems:  8,
		MaxSearchRunes:  520,
	}
}

// BootstrapInput 注入块输入。
type BootstrapInput struct {
	Profiles    []ProfileSummary
	DailyNotes  []Record
	SearchItems []DisplayItem
	Budget      BootstrapBudget
}

// ComposeBootstrap 生成追加到 system 的记忆块（不含基础人设）。
func ComposeBootstrap(in BootstrapInput) string {
	b := in.Budget
	if b.MaxProfileRunes <= 0 && b.MaxDailyRunes <= 0 && b.MaxSearchRunes <= 0 {
		b = DefaultBootstrapBudget()
	}
	var parts []string

	if block := formatProfilesBlock(in.Profiles, b.MaxProfileRunes); block != "" {
		parts = append(parts, block)
	}
	if block := FormatDailyNotesBlock(in.DailyNotes, b.MaxDailyRunes); block != "" {
		parts = append(parts, block)
	}
	if block := formatSearchBlock(in.SearchItems, b.MaxSearchItems, b.MaxSearchRunes); block != "" {
		parts = append(parts, block)
	}

	if len(parts) == 0 {
		return ""
	}
	var out strings.Builder
	out.WriteString(strings.Join(parts, "\n\n"))
	out.WriteString("\n\n请把以上信息当作你已了解的用户背景，在合适时自然参考，不要机械复述。")
	return out.String()
}

func formatProfilesBlock(profiles []ProfileSummary, maxRunes int) string {
	if len(profiles) == 0 || maxRunes <= 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("=== 用户长期画像（精选层 / MEMORY）===\n")
	used := len([]rune(b.String()))
	limit := 6
	if limit > len(profiles) {
		limit = len(profiles)
	}
	for i := 0; i < limit; i++ {
		p := profiles[i]
		if strings.TrimSpace(p.Summary) == "" {
			continue
		}
		label := CategoryLabel(p.MemoryType, "")
		line := fmt.Sprintf("- %s：%s", label, strings.TrimSpace(p.Summary))
		runes := len([]rune(line)) + 1
		if used+runes > maxRunes && used > 0 {
			break
		}
		b.WriteString(line)
		b.WriteString("\n")
		used += runes
	}
	if used <= len([]rune("=== 用户长期画像（精选层 / MEMORY）===\n")) {
		return ""
	}
	return strings.TrimSpace(b.String())
}

func formatSearchBlock(items []DisplayItem, maxItems, maxRunes int) string {
	if len(items) == 0 || maxRunes <= 0 {
		return ""
	}
	if maxItems <= 0 {
		maxItems = 8
	}
	var b strings.Builder
	b.WriteString("=== 与本句相关的记忆检索 ===\n")
	used := len([]rune(b.String()))
	count := 0
	for _, it := range items {
		if count >= maxItems {
			break
		}
		content := strings.TrimSpace(it.Content)
		if content == "" {
			continue
		}
		line := "- " + content
		if t := strings.TrimSpace(it.Title); t != "" && t != content {
			line = fmt.Sprintf("- %s：%s", t, content)
		}
		runes := len([]rune(line)) + 1
		if used+runes > maxRunes && count > 0 {
			break
		}
		b.WriteString(line)
		b.WriteString("\n")
		used += runes
		count++
	}
	if count == 0 {
		return ""
	}
	return strings.TrimSpace(b.String())
}
