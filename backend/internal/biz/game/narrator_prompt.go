package gamebiz

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"backend/model"
)

// buildNarratorSceneBlock 小模型专用：极短场景事实，避免结构化标签诱发「设定文档」式输出。
func buildNarratorSceneBlock(scene model.GameScene, brief string, npcs []NpcView, gameTime string) string {
	desc := trimRunes(strings.TrimSpace(scene.Description), 72)
	var b strings.Builder
	b.WriteString(fmt.Sprintf("你在「%s」", scene.Name))
	if desc != "" {
		b.WriteString("，" + desc)
	}
	b.WriteString("。")
	if brief != "" {
		b.WriteString("\n刚发生：" + trimRunes(brief, 120))
	}
	if len(npcs) > 0 {
		b.WriteString("\n在场：")
		for i, n := range npcs {
			if i >= 3 {
				break
			}
			if i > 0 {
				b.WriteString("、")
			}
			b.WriteString(n.Name)
		}
	}
	if t := strings.TrimSpace(gameTime); t != "" {
		b.WriteString("\n时间：" + t)
	}
	return b.String()
}

// buildNarratorPromptProse 小模型专用：一段话回复，禁止写设定文档。
func buildNarratorPromptProse(ctx actPromptContext) string {
	return strings.TrimSpace(`用聊天口吻接玩家的话，写 80-150 字的一个自然段（可含一句 NPC 台词）。
不要标题、不要分节、不要列表、不要 JSON、不要写「故事背景/角色设定/场景描写/世界观」。

` + ctx.sceneBlock + `
玩家：` + ctx.action + `
`)
}

var narratorDocMarkers = []string{
	"故事背景", "角色设定", "场景描写", "世界观", "细致的人设", "一个故事的开头",
	"【世界观", "## ", "### ",
}

// sanitizeNarratorProse 去掉小模型常见的复读/设定文档格式。
func sanitizeNarratorProse(prose string) string {
	prose = strings.TrimSpace(prose)
	if prose == "" {
		return prose
	}
	prose = stripNarratorDocSections(prose)
	prose = dedupeChineseSentences(prose)
	parts := strings.Split(prose, "\n\n")
	seen := map[string]struct{}{}
	var kept []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if utf8.RuneCountInString(p) < 6 {
			continue
		}
		key := p
		if utf8.RuneCountInString(key) > 64 {
			key = string([]rune(key)[:64])
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		kept = append(kept, p)
	}
	if len(kept) == 0 {
		return trimRunes(prose, 180)
	}
	out := kept[0]
	if len(kept) > 1 && utf8.RuneCountInString(out) < 40 {
		out = kept[0] + kept[1]
	}
	return trimRunes(out, 180)
}

func stripNarratorDocSections(prose string) string {
	for {
		changed := false
		for _, marker := range narratorDocMarkers {
			idx := strings.Index(prose, marker)
			if idx < 0 {
				continue
			}
			if idx == 0 {
				if nl := strings.Index(prose, "\n"); nl >= 0 {
					prose = strings.TrimSpace(prose[nl+1:])
				} else {
					prose = ""
				}
			} else {
				prose = strings.TrimSpace(prose[:idx])
			}
			changed = true
			break
		}
		if !changed || prose == "" {
			break
		}
	}
	return prose
}

func dedupeChineseSentences(prose string) string {
	var parts []string
	var cur strings.Builder
	flush := func() {
		s := strings.TrimSpace(cur.String())
		cur.Reset()
		if s != "" {
			parts = append(parts, s)
		}
	}
	for _, r := range prose {
		cur.WriteRune(r)
		if r == '。' || r == '！' || r == '？' || r == '\n' {
			flush()
		}
	}
	flush()
	if len(parts) <= 1 {
		return prose
	}
	seen := map[string]struct{}{}
	var kept []string
	for _, s := range parts {
		key := s
		if utf8.RuneCountInString(key) > 48 {
			key = string([]rune(key)[:48])
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		kept = append(kept, s)
	}
	return strings.Join(kept, "")
}

func trimRunes(s string, max int) string {
	rs := []rune(strings.TrimSpace(s))
	if len(rs) <= max {
		return string(rs)
	}
	return string(rs[:max]) + "…"
}
