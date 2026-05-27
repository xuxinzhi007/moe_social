package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/brain"
)

// DeleteBrainEpisode 删除一条自传 episode。
func DeleteBrainEpisode(ctx context.Context, deps brain.Deps, episodeID uint) error {
	return brain.DeleteEpisode(ctx, deps, episodeID)
}

// RefineBrainEpisode 润色单条 episode。
func RefineBrainEpisode(ctx context.Context, deps brain.RefineDeps, episodeID uint, opts brain.RefineOptions) (brain.RefineResult, error) {
	return brain.RefineEpisode(ctx, deps, episodeID, opts)
}

// CurateBrain 批量润色低质量 episode。
func CurateBrain(ctx context.Context, deps brain.RefineDeps, agentKey string, opts brain.CurateOptions) ([]brain.RefineResult, error) {
	return brain.CurateLowQuality(ctx, deps, strings.TrimSpace(agentKey), opts)
}
