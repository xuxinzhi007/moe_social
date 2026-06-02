package adminbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	adminv1 "backend/api/admin/v1"
	llmv1 "backend/api/llm/v1"
	"backend/internal/adapter/moeconfig"
	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	llmbiz "backend/internal/biz/llm"
	llmdata "backend/internal/data/llm"

	"gorm.io/gorm"
)

// RebuildMemoryEmbeddings Admin 触发单用户向量重建（llama.cpp embedding 链）。
func RebuildMemoryEmbeddings(ctx context.Context, db *gorm.DB, in *adminv1.AdminRebuildMemoryEmbeddingsReq) (*adminv1.AdminRebuildMemoryEmbeddingsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID := strings.TrimSpace(in.GetUserId())
	if userID == "" {
		return nil, fmt.Errorf("user_id 不能为空")
	}
	inference := moeconfig.InferenceFromViper()
	st := llmdata.NewStore(db)
	if st == nil {
		return nil, gorm.ErrInvalidDB
	}
	resp, err := llmbiz.RebuildUserMemoryEmbeddings(ctx, st, &llmv1.RebuildUserMemoryEmbeddingsReq{
		UserId: userID,
	}, inference.BaseURL)
	if err != nil {
		return &adminv1.AdminRebuildMemoryEmbeddingsResp{
			Message: err.Error(),
		}, nil
	}
	msg := fmt.Sprintf("已索引 %d 条", resp.GetIndexed())
	if resp.GetProvider() != "" {
		msg += fmt.Sprintf("（%s / %s）", resp.GetProvider(), resp.GetModel())
	}
	return &adminv1.AdminRebuildMemoryEmbeddingsResp{
		Indexed:  resp.GetIndexed(),
		Provider: resp.GetProvider(),
		Model:    resp.GetModel(),
		Message:  msg,
	}, nil
}

// ExportLearningDataset 从酒馆角色卡导出 LoRA 训练用 JSONL（单行 messages 格式）。
func ExportLearningDataset(ctx context.Context, db *gorm.DB, in *adminv1.AdminExportLearningDatasetReq) (*adminv1.AdminExportLearningDatasetResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID := strings.TrimSpace(in.GetUserId())
	agentID := strings.TrimSpace(in.GetAgentId())
	if userID == "" || agentID == "" {
		return nil, fmt.Errorf("user_id 与 agent_id 均不能为空")
	}

	uid, err := aibiz.ParseUserID(userID)
	if err != nil {
		return nil, err
	}
	cfg, err := aidata.NewStore(db).WithContext(ctx).LoadOrCreateConfig(ctx, uid)
	if err != nil {
		return nil, err
	}
	agents := aibiz.DecodeJSONArray(cfg.AgentsJSON)
	var picked map[string]interface{}
	for _, item := range agents {
		if fmt.Sprint(item["id"]) == agentID {
			picked = item
			break
		}
	}
	if picked == nil {
		return nil, fmt.Errorf("未找到 agent_id=%s", agentID)
	}

	name := strings.TrimSpace(fmt.Sprint(picked["name"]))
	system := strings.TrimSpace(fmt.Sprint(picked["system_prompt"]))
	if system == "" {
		system = strings.TrimSpace(fmt.Sprint(picked["persona"]))
	}
	opening := strings.TrimSpace(fmt.Sprint(picked["opening_message"]))
	examples := strings.TrimSpace(fmt.Sprint(picked["example_dialogues"]))

	lines := make([]string, 0, 8)
	if system != "" {
		lines = append(lines, marshalTrainingLine([]map[string]string{
			{"role": "system", "content": system},
			{"role": "user", "content": "你好"},
			{"role": "assistant", "content": openingOrDefault(opening, "你好，我在呢。")},
		}))
	}
	for _, ex := range parseExampleDialogues(examples) {
		msgs := []map[string]string{{"role": "system", "content": system}}
		msgs = append(msgs, ex...)
		if len(msgs) >= 2 {
			lines = append(lines, marshalTrainingLine(msgs))
		}
	}
	if len(lines) == 0 {
		return nil, fmt.Errorf("角色卡缺少 system_prompt / example_dialogues，无法生成训练集")
	}

	return &adminv1.AdminExportLearningDatasetResp{
		Jsonl:     strings.Join(lines, "\n") + "\n",
		LineCount: int32(len(lines)),
		AgentName: name,
		Hint:      "保存为 tools/character-finetune/datasets/<角色>/train.jsonl 后执行 run_train.sh（llama.cpp 路线，非 Ollama）",
	}, nil
}

func openingOrDefault(opening, fallback string) string {
	if strings.TrimSpace(opening) != "" {
		return strings.TrimSpace(opening)
	}
	return fallback
}

func marshalTrainingLine(messages []map[string]string) string {
	b, _ := json.Marshal(map[string]any{"messages": messages})
	return string(b)
}

func parseExampleDialogues(raw string) [][]map[string]string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	// 简单分段：按「用户：」「助手：」或 User/Assistant 行拆成一轮
	var blocks [][]map[string]string
	lines := strings.Split(raw, "\n")
	var cur []map[string]string
	flush := func() {
		if len(cur) >= 2 {
			blocks = append(blocks, append([]map[string]string(nil), cur...))
		}
		cur = nil
	}
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			flush()
			continue
		}
		if strings.HasPrefix(line, "用户：") || strings.HasPrefix(line, "User:") {
			if len(cur) > 0 {
				flush()
			}
			cur = append(cur, map[string]string{"role": "user", "content": trimDialoguePrefix(line)})
			continue
		}
		if strings.HasPrefix(line, "助手：") || strings.HasPrefix(line, "Assistant:") {
			cur = append(cur, map[string]string{"role": "assistant", "content": trimDialoguePrefix(line)})
			continue
		}
		if len(cur) > 0 {
			last := cur[len(cur)-1]["content"] + "\n" + line
			cur[len(cur)-1]["content"] = strings.TrimSpace(last)
		}
	}
	flush()
	return blocks
}

func trimDialoguePrefix(line string) string {
	for _, p := range []string{"用户：", "助手：", "User:", "Assistant:"} {
		if strings.HasPrefix(line, p) {
			return strings.TrimSpace(strings.TrimPrefix(line, p))
		}
	}
	return line
}
