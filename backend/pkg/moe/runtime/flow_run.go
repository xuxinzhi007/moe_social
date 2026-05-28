package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/core"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
)

type flowRunState struct {
	rt          model.MoeAgentRuntime
	gen         GeneratedPost
	genAttempts []GenAttemptRecord
	postID      string
	tier        core.CapabilityTier
	exec        *tools.Executor
	loaded      bool
}

func executeFlowPlan(
	ctx context.Context,
	deps Deps,
	agentKey string,
	plan flowexec.Plan,
	rec *StepRecorder,
) (RunOnceResult, flowRunState, error) {
	st := flowRunState{}
	for _, node := range plan.Nodes {
		kind := flowexec.NodeExecKind(node)
		stepStart := time.Now()
		switch kind {
		case "load_runtime":
			if err := deps.DB.Where("agent_key = ? AND enabled = ?", agentKey, true).First(&st.rt).Error; err != nil {
				rec.Add("load_runtime", "加载 Bot 配置", "fail", err.Error(), time.Since(stepStart))
				return RunOnceResult{AgentKey: agentKey, OK: false, Detail: err.Error()}, st, err
			}
			st.loaded = true
			st.tier = core.ParseTier(st.rt.CapabilityTier)
			st.exec = tools.NewExecutor(tools.Deps{DB: deps.DB, RPC: deps.RPC})
			rec.Add("load_runtime", "加载 Bot 配置", "ok", st.rt.DisplayName, time.Since(stepStart))

		case "gather_memory":
			if !st.loaded {
				return RunOnceResult{AgentKey: agentKey, OK: false, Detail: "gather 在 load 之前"}, st, fmt.Errorf("gather before load")
			}
			memDetail := "组装发帖 prompt"
			if deps.DB != nil && st.rt.BotUserID > 0 {
				ownN := len(listBotRecentPosts(deps.DB, st.rt.BotUserID, botRecentPostLimit))
				epN := len(brain.ListRecentEpisodes(deps.DB, st.rt.AgentKey, 12))
				memDetail = fmt.Sprintf("近期帖 %d · 自传 %d · 社区脉搏", ownN, epN)
			}
			rec.Add("gather_memory", "检索记忆与社区脉搏", "ok", memDetail, time.Since(stepStart))

		case "prep":
			key := node.StepKey
			if key == "" {
				key = "topic_profile"
			}
			rec.Add(key, flowexec.NodeLabel(node, "编排 Prompt"), "ok", "画布节点", time.Since(stepStart))

		case "llm_generate":
			if !st.loaded {
				return RunOnceResult{AgentKey: agentKey, OK: false, Detail: "llm 在 load 之前"}, st, fmt.Errorf("llm before load")
			}
			var genErr error
			st.gen, st.genAttempts, genErr = generatePostContent(ctx, deps, st.rt, rec)
			if genErr != nil {
				runDetail := FormatRunDetailFromGen(st.genAttempts, false, "", genErr)
				return RunOnceResult{AgentKey: st.rt.AgentKey, OK: false, Detail: runDetail}, st, genErr
			}

		case "qc":
			rec.Add("generate_finalize", flowexec.NodeLabel(node, "质检汇总"), "ok", "画布节点", time.Since(stepStart))

		case "post_create", "tool":
			toolName := "post_create"
			if node.Type == "tool" && node.ToolName != "" {
				toolName = node.ToolName
			}
			if toolName != "post_create" {
				rec.Add(toolName, flowexec.NodeLabel(node, toolName), "skip", "E1 发帖路径仅执行 post_create", time.Since(stepStart))
				continue
			}
			if st.exec == nil {
				st.exec = tools.NewExecutor(tools.Deps{DB: deps.DB, RPC: deps.RPC})
			}
			argsJSON, _ := json.Marshal(map[string]string{"content": st.gen.Content, "mood_tag": st.gen.MoodTag})
			execReq := core.ExecuteRequest{
				Tool: toolName, ArgumentsJSON: string(argsJSON),
				BotUserID: st.rt.BotUserID, ActorUserID: st.rt.BotUserID,
				AgentKey: st.rt.AgentKey, Tier: st.tier,
			}
			toolRes := st.exec.Execute(ctx, execReq)
			postDur := time.Since(stepStart)
			toolaudit.Record(deps.DB, toolaudit.RecordInput{
				Tool: toolName, ArgumentsJSON: execReq.ArgumentsJSON,
				ActorUserID: execReq.ActorUserID, BotUserID: execReq.BotUserID,
				AgentKey: execReq.AgentKey, Ok: toolRes.OK, ErrorMsg: toolRes.Error,
				LatencyMs: int(postDur.Milliseconds()), Source: "runtime",
			})
			if !toolRes.OK {
				rec.Add("post_create", "发布动态", "fail", toolRes.Error, postDur)
				runDetail := FormatRunDetailFromGen(st.genAttempts, false, "", fmt.Errorf("%s", toolRes.Error))
				return RunOnceResult{AgentKey: st.rt.AgentKey, OK: false, Detail: runDetail}, st, fmt.Errorf("%s", toolRes.Error)
			}
			rec.Add("post_create", "发布动态", "ok", fmt.Sprintf("%dms", postDur.Milliseconds()), postDur)
			var parsed map[string]any
			if json.Unmarshal([]byte(toolRes.Result), &parsed) == nil {
				if id, ok := parsed["post_id"].(string); ok {
					st.postID = id
				}
			}

		case "record_episode":
			if st.postID == "" {
				rec.Add("record_episode", "写入自传与话题标签", "skip", "无 post_id", time.Since(stepStart))
				continue
			}
			epStart := time.Now()
			styleScore := novelStyleScore(st.gen.Content)
			_ = brain.RecordEpisode(ctx, brain.Deps{DB: deps.DB, RPC: deps.RPC, Inference: deps.Inference}, brain.RecordInput{
				AgentKey: st.rt.AgentKey, BotUserID: st.rt.BotUserID, PostID: st.postID,
				Content: st.gen.Content, MoodTag: st.gen.MoodTag, StyleScore: styleScore, Source: st.gen.Source,
			})
			rec.Add("record_episode", "写入自传与话题标签", "ok", st.postID, time.Since(epStart))

		default:
			rec.Add(kind, flowexec.NodeLabel(node, kind), "skip", "未识别", time.Since(stepStart))
		}
	}
	out := RunOnceResult{AgentKey: st.rt.AgentKey, OK: true}
	if st.postID != "" {
		out.PostID = st.postID
		out.Detail = FormatRunDetailFromGen(st.genAttempts, true, st.gen.Source, nil)
		if out.Detail == "" {
			out.Detail = fmt.Sprintf("ai_post(%s)", st.gen.Source)
		}
	}
	return out, st, nil
}
