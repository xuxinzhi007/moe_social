package adminbiz

import (
	"context"
	"net/http"
	"strings"
	"time"

	adminv1 "backend/api/admin/v1"
	"backend/internal/adapter/moeconfig"
	"backend/pkg/llminference"
	"backend/pkg/memory/embed"

	"github.com/spf13/viper"
)

// GetMemoryHealth 记忆检索 / embedding / llama.cpp 健康快照（管理台学习工作台）。
func GetMemoryHealth(ctx context.Context, store AdminStore) (*adminv1.AdminGetMemoryHealthResp, error) {
	if store == nil {
		return nil, ErrMemoryStats
	}
	statsResp, err := GetMemoryStats(ctx, store, &adminv1.AdminGetMemoryStatsReq{})
	if err != nil {
		return nil, err
	}
	stats := statsResp.GetStats()
	out := &adminv1.AdminGetMemoryHealthResp{
		Stats: stats,
	}
	if stats != nil && stats.GetTotalMemories() > 0 {
		out.EmbeddingIndexRatio = float64(stats.GetTotalEmbeddings()) / float64(stats.GetTotalMemories())
	}

	loadMemorySearchConfig(out)
	inference := moeconfig.InferenceFromViper()
	out.LlmInferenceBaseUrl = strings.TrimSpace(inference.BaseURL)
	out.MemoryModel = strings.TrimSpace(inference.DefaultModel)

	probeCtx, cancel := context.WithTimeout(ctx, 12*time.Second)
	defer cancel()
	out.EmbeddingProbe = probeEmbedding(probeCtx, out.LlmInferenceBaseUrl)
	out.LlmInferenceOnline = probeLLMInference(probeCtx, inference)

	out.Hints = buildMemoryHealthHints(out)
	return out, nil
}

func loadMemorySearchConfig(out *adminv1.AdminGetMemoryHealthResp) {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()

	out.HybridEnabled = v.GetBool("memory.search.hybrid_enabled")
	if !v.IsSet("memory.search.hybrid_enabled") {
		out.HybridEnabled = true
	}
	out.VectorWeight = v.GetFloat64("memory.search.vector_weight")
	if out.VectorWeight <= 0 {
		out.VectorWeight = 0.7
	}
	out.KeywordWeight = v.GetFloat64("memory.search.keyword_weight")
	if out.KeywordWeight <= 0 {
		out.KeywordWeight = 0.3
	}
	out.RerankEnabled = v.GetBool("memory.search.rerank_enabled")
	if !v.IsSet("memory.search.rerank_enabled") {
		out.RerankEnabled = true
	}
	out.GraphEnabled = v.GetBool("memory.search.graph_enabled")
	if !v.IsSet("memory.search.graph_enabled") {
		out.GraphEnabled = true
	}
}

func probeEmbedding(ctx context.Context, inferenceBaseURL string) *adminv1.AdminEmbeddingProbe {
	providers := embed.LoadProviders(inferenceBaseURL)
	if len(providers) == 0 {
		return &adminv1.AdminEmbeddingProbe{
			Ok:      false,
			Message: "未配置 memory.embedding 提供方",
		}
	}
	p0 := providers[0]
	probe := &adminv1.AdminEmbeddingProbe{
		ProviderType: p0.Type,
		Model:        p0.Model,
		BaseUrl:      p0.BaseURL,
	}
	chain := embed.NewChain(providers)
	_, provider, model, err := chain.Embed(ctx, []string{"memory health probe"})
	if err != nil {
		probe.Message = err.Error()
		return probe
	}
	probe.Ok = true
	probe.ProviderType = provider
	probe.Model = model
	probe.Message = "embedding 探测成功"
	return probe
}

func probeLLMInference(ctx context.Context, cfg llminference.Config) bool {
	base := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if base == "" {
		return false
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/v1/models", nil)
	if err != nil {
		return false
	}
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func buildMemoryHealthHints(out *adminv1.AdminGetMemoryHealthResp) []string {
	var hints []string
	stats := out.GetStats()
	if stats != nil {
		if stats.GetTotalMemories() > 0 && out.GetEmbeddingIndexRatio() < 0.5 {
			hints = append(hints, "向量索引覆盖率偏低：对目标用户执行「重建索引」，并确认 llama-server 已开启 /v1/embeddings")
		}
		if stats.GetTotalMemories() == 0 {
			hints = append(hints, "尚无用户记忆：App 需登录且勿开终端调试模式，聊天后才会写入 user_memories")
		}
	}
	if ep := out.GetEmbeddingProbe(); ep != nil && !ep.GetOk() {
		msg := strings.ToLower(ep.GetMessage())
		if strings.Contains(msg, "does not support embeddings") || strings.Contains(msg, "\"code\":501") {
			hints = append(hints,
				"llama-server 未开 embedding：启动时加 --embeddings（或与 chat 分端口部署 embed 模型），否则向量条数/混合检索无效")
		} else {
			hints = append(hints, "Embedding 不可用：检查 memory.embedding（默认与 llm_inference 同址 :6633）及 embed 模型")
		}
	}
	if !out.GetLlmInferenceOnline() {
		hints = append(hints, "llama-server 离线：记忆 LLM 提取与 Bot 依赖 llm_inference.base_url")
	}
	if out.GetHybridEnabled() && (out.GetEmbeddingProbe() == nil || !out.GetEmbeddingProbe().GetOk()) {
		hints = append(hints, "混合检索将退化为关键词，paraphrase 召回可能变差")
	}
	hints = append(hints, "账号记忆（RAG）与角色 LoRA 分离：训练改口吻，用户事实仍走记忆库")
	return hints
}
