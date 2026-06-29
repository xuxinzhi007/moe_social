package brain

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/llminference"
)

// PendingDeleteMark 压缩后标记、下轮清扫删除。
type PendingDeleteMark struct {
	Kind     string `json:"kind"`
	Ref      string `json:"ref"`
	MarkedAt string `json:"marked_at"`
}

type compressCandidate struct {
	EpisodeID uint
	MemoryKey string
	Content   string
	Tags      []string
}

type episodeCluster struct {
	items []compressCandidate
}

func compressMarkSweep(
	ctx context.Context,
	deps RpgDeps,
	rt model.MoeAgentRuntime,
	cfg RpgConfig,
	candidates []compressCandidate,
) (summary string, swept, mergedClusters, marked int, newPending []PendingDeleteMark, err error) {
	recordDeps := Deps{DB: deps.DB, RPC: deps.RPC, Inference: deps.Inference.Inference}

	for _, mark := range cfg.PendingDeletes {
		if sweepPendingDelete(ctx, recordDeps, rt, mark) {
			swept++
		}
	}

	clusters := clusterCandidates(candidates)
	mergedLines := make([]string, 0, len(clusters))
	now := time.Now().Format("2006-01-02 15:04:05")

	for _, cl := range clusters {
		if len(cl.items) < 2 {
			continue
		}
		mergedClusters++
		texts := make([]string, 0, len(cl.items))
		for _, it := range cl.items {
			texts = append(texts, it.Content)
		}
		line := mergeClusterTexts(texts)
		if line == "" {
			continue
		}
		if deps.Inference.Inference.Ready() {
			if rewritten, rerr := rewriteMergedMemory(ctx, deps.Inference.Inference, rt.DisplayName, texts, line); rerr == nil && rewritten != "" {
				line = rewritten
			}
		}
		mergedLines = append(mergedLines, line)
		for _, it := range cl.items {
			newPending = append(newPending, PendingDeleteMark{
				Kind:     "episode",
				Ref:      strconv.FormatUint(uint64(it.EpisodeID), 10),
				MarkedAt: now,
			})
			marked++
		}
	}

	if len(mergedLines) == 0 {
		if swept > 0 {
			summary = fmt.Sprintf("已清扫 %d 条上轮标记；本轮无可合并簇", swept)
			return summary, swept, 0, 0, nil, nil
		}
		return "", swept, 0, 0, nil, fmt.Errorf("未发现可合并的重复/零散碎片")
	}

	sort.Strings(mergedLines)
	summary = "【压缩合并】" + strings.Join(mergedLines, " | ")
	return summary, swept, mergedClusters, marked, newPending, nil
}

func clusterCandidates(items []compressCandidate) []episodeCluster {
	if len(items) < 2 {
		return nil
	}
	used := make([]bool, len(items))
	var out []episodeCluster
	for i := range items {
		if used[i] {
			continue
		}
		cl := episodeCluster{items: []compressCandidate{items[i]}}
		used[i] = true
		for j := i + 1; j < len(items); j++ {
			if used[j] {
				continue
			}
			ok := false
			for _, base := range cl.items {
				if shouldCluster(base.Content, items[j].Content, base.Tags, items[j].Tags) {
					ok = true
					break
				}
			}
			if ok {
				cl.items = append(cl.items, items[j])
				used[j] = true
			}
		}
		if len(cl.items) >= 2 {
			out = append(out, cl)
		}
	}
	return out
}

func sweepPendingDelete(ctx context.Context, deps Deps, rt model.MoeAgentRuntime, mark PendingDeleteMark) bool {
	switch mark.Kind {
	case "episode":
		id, err := strconv.ParseUint(strings.TrimSpace(mark.Ref), 10, 64)
		if err != nil || id == 0 {
			return false
		}
		return DeleteEpisode(ctx, deps, uint(id)) == nil
	default:
		return false
	}
}

func rewriteMergedMemory(ctx context.Context, inf llminference.Config, botName string, sources []string, merged string) (string, error) {
	if !inf.Ready() {
		return merged, nil
	}
	modelName := strings.TrimSpace(inf.DefaultModel)
	if modelName == "" {
		return merged, nil
	}
	sys := "你是记忆压缩助手。把多条相似碎片合并成一条新记忆：换说法、换角度，不要照搬原句。只输出 JSON：{\"narrative\":\"...\"}"
	user := fmt.Sprintf("Bot：%s\n碎片：\n- %s\n算法草稿：%s", botName, strings.Join(sources, "\n- "), merged)
	raw, err := llminference.Chat(ctx, inf, modelName, []llminference.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, llminference.ChatOptions{Temperature: 0.9, TopP: 0.92, MaxTokens: 220})
	if err != nil {
		return merged, err
	}
	n, err := parseDreamNarrativeJSON(raw)
	if err != nil || n == "" {
		return merged, nil
	}
	return n, nil
}
