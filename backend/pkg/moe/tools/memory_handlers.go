package tools

import (
	"context"
	"strconv"

	"backend/pkg/memory"
	"backend/pkg/moe/core"

	llmv1 "backend/api/llm/v1"
)

type memorySearchArgs struct {
	Query string `json:"query"`
	Limit int    `json:"limit"`
}

type memoryGetArgs struct {
	Key string `json:"key"`
}

type memorySaveArgs struct {
	Key        string `json:"key"`
	Value      string `json:"value"`
	MemoryType string `json:"memory_type"`
}

func (e *Executor) execMemorySearch(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	if req.ActorUserID == 0 {
		return fail("需要 actor_user_id")
	}
	var args memorySearchArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	uid := strconv.FormatUint(uint64(req.ActorUserID), 10)
	memResp, err := e.deps.RPC.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{UserId: uid})
	if err != nil {
		return fail("拉取记忆失败")
	}
	records := memory.RecordsFromLLMV1(memResp.GetMemories())
	limit := args.Limit
	if limit <= 0 {
		limit = 5
	}
	res := memory.SearchFacing(records, args.Query, limit)
	items := make([]map[string]any, 0, len(res.Items))
	for _, it := range res.Items {
		items = append(items, map[string]any{
			"key":     it.Key,
			"content": it.Content,
			"type":    it.Category,
		})
	}
	return ok(map[string]any{"items": items, "total": len(items)})
}

func (e *Executor) execMemoryGet(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	if req.ActorUserID == 0 {
		return fail("需要 actor_user_id")
	}
	var args memoryGetArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	uid := strconv.FormatUint(uint64(req.ActorUserID), 10)
	memResp, err := e.deps.RPC.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{UserId: uid})
	if err != nil {
		return fail("拉取记忆失败")
	}
	for _, m := range memResp.GetMemories() {
		if m != nil && m.GetKey() == args.Key {
			return ok(map[string]any{"key": m.GetKey(), "value": m.GetValue(), "type": m.GetMemoryType()})
		}
	}
	return ok(map[string]any{"key": args.Key, "value": "", "found": false})
}

func (e *Executor) execMemorySave(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	if req.ActorUserID == 0 {
		return fail("需要 actor_user_id")
	}
	var args memorySaveArgs
	if err := parseArgs(req.ArgumentsJSON, &args); err != nil {
		return fail(err.Error())
	}
	uid := strconv.FormatUint(uint64(req.ActorUserID), 10)
	mt := args.MemoryType
	if mt == "" {
		mt = "fact"
	}
	_, err := e.deps.RPC.UpsertUserMemory(ctx, &llmv1.UpsertUserMemoryReq{
		UserId:     uid,
		Key:        args.Key,
		Value:      args.Value,
		MemoryType: mt,
		Source:     "moe_tool",
	})
	if err != nil {
		return fail("保存记忆失败")
	}
	return ok(map[string]any{"saved": true, "key": args.Key})
}
