package tools

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"

	"backend/pkg/llminference"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/core"
)

func (e *Executor) execBrainRefineEpisode(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	if !e.deps.Inference.Ready() {
		return fail("未配置 llm_inference，无法润色记忆")
	}
	var args struct {
		EpisodeID   uint   `json:"episode_id"`
		MaxAttempts int    `json:"max_attempts"`
	}
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	if args.EpisodeID == 0 {
		return fail("episode_id 必填")
	}
	res, err := brain.RefineEpisode(ctx, brain.RefineDeps{
		DB:        e.deps.DB,
		RPC:       e.deps.RPC,
		Inference: e.deps.Inference,
	}, args.EpisodeID, brain.RefineOptions{MaxAttempts: args.MaxAttempts})
	if err != nil && !res.OK {
		return fail(err.Error())
	}
	return ok(res)
}

func (e *Executor) execBrainCurateMemories(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	if !e.deps.Inference.Ready() {
		return fail("未配置 llm_inference，无法整理记忆")
	}
	agentKey := req.AgentKey
	var args struct {
		AgentKey    string `json:"agent_key"`
		MaxEpisodes int    `json:"max_episodes"`
		MaxAttempts int    `json:"max_attempts"`
		MinQuality  int    `json:"min_quality"`
		Force       bool   `json:"force"`
	}
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	if agentKey == "" {
		agentKey = args.AgentKey
	}
	if agentKey == "" {
		return fail("agent_key 必填")
	}
	results, err := brain.CurateLowQuality(ctx, brain.RefineDeps{
		DB:        e.deps.DB,
		RPC:       e.deps.RPC,
		Inference: e.deps.Inference,
	}, agentKey, brain.CurateOptions{
		MaxEpisodes:           args.MaxEpisodes,
		MaxAttemptsPerEpisode: args.MaxAttempts,
		MinQuality:            args.MinQuality,
		Force:                 args.Force,
	})
	if err != nil {
		return fail(err.Error())
	}
	approved := 0
	for _, r := range results {
		if r.Approved {
			approved++
		}
	}
	payload := map[string]any{
		"agent_key": agentKey,
		"total":     len(results),
		"approved":  approved,
		"results":   results,
	}
	b, _ := json.Marshal(payload)
	return core.ExecuteResult{OK: true, Result: string(b)}
}

// ParseEpisodeIDArg 解析 episode_id 参数。
func ParseEpisodeIDArg(raw string) (uint, error) {
	var args struct {
		EpisodeID json.Number `json:"episode_id"`
	}
	if err := parseArgs(raw, &args); err != nil {
		return 0, err
	}
	n, err := args.EpisodeID.Int64()
	if err != nil {
		v, perr := strconv.ParseUint(string(args.EpisodeID), 10, 32)
		if perr != nil {
			return 0, fmt.Errorf("episode_id 无效")
		}
		return uint(v), nil
	}
	if n <= 0 {
		return 0, fmt.Errorf("episode_id 无效")
	}
	return uint(n), nil
}

// InferenceFromConfig 供 bridge 注入。
func InferenceFromConfig(cfg llminference.Config) llminference.Config {
	return cfg
}
