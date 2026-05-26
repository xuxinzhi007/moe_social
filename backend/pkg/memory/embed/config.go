package embed

import (
	"os"
	"strings"

	"github.com/spf13/viper"
)

// ProviderConfig 单路 embedding 配置。
type ProviderConfig struct {
	Type     string // ollama | openai_compatible
	BaseURL  string
	APIKey   string
	Model    string
	Priority int
}

// HybridConfig 混合检索权重（OpenClaw 默认向量偏高）。
type HybridConfig struct {
	Enabled       bool
	VectorWeight  float64
	KeywordWeight float64
}

// RerankConfig 重排序（pkg/memory 域配置镜像）。
type RerankConfig struct {
	Enabled   bool
	TopK      int
	MMRLambda float64
}

// GraphConfig 图谱扩展配置镜像。
type GraphConfig struct {
	Enabled   bool
	Hops      int
	Boost     float64
	MaxExpand int
}

// LoadProviders 从 backend/config/config.yaml（viper）加载，按 Priority 升序尝试。
func LoadProviders(ollamaBaseURL string) []ProviderConfig {
	_ = ensureViper()
	var out []ProviderConfig

	if viper.IsSet("memory.embedding.providers") {
		raw := viper.Get("memory.embedding.providers")
		if list, ok := raw.([]any); ok {
			for _, item := range list {
				m, ok := item.(map[string]any)
				if !ok {
					continue
				}
				pc := mapToProvider(m)
				if pc.Type != "" {
					out = append(out, pc)
				}
			}
		}
	}

	if len(out) == 0 {
		oBase := strings.TrimSpace(viper.GetString("memory.embedding.openai_base_url"))
		if oBase == "" {
			oBase = strings.TrimSpace(viper.GetString("llm_inference.base_url"))
		}
		if oBase == "" {
			oBase = strings.TrimSpace(ollamaBaseURL)
		}
		if oBase == "" {
			oBase = strings.TrimSpace(viper.GetString("ollama.base_url"))
		}
		oKey := strings.TrimSpace(viper.GetString("memory.embedding.openai_api_key"))
		if oKey == "" {
			oKey = strings.TrimSpace(os.Getenv("MOE_MEMORY_EMBED_API_KEY"))
		}
		if oKey == "" && oBase != "" {
			oKey = "local"
		}
		oModel := strings.TrimSpace(viper.GetString("memory.embedding.openai_model"))
		if oModel == "" {
			oModel = strings.TrimSpace(viper.GetString("llm_inference.memory_model"))
		}
		if oBase != "" {
			out = append(out, ProviderConfig{
				Type:     "openai_compatible",
				BaseURL:  oBase,
				APIKey:   oKey,
				Model:    oModel,
				Priority: 1,
			})
		}
		// 遗留 Ollama embedding（仅当显式配置 ollama_model 且 api_style=ollama）
		legacyBase := strings.TrimSpace(ollamaBaseURL)
		if legacyBase == "" {
			legacyBase = strings.TrimSpace(viper.GetString("ollama.base_url"))
		}
		legacyStyle := strings.ToLower(strings.TrimSpace(viper.GetString("llm_inference.api_style")))
		if legacyStyle == "" {
			legacyStyle = strings.ToLower(strings.TrimSpace(viper.GetString("ollama.api_style")))
		}
		legacyModel := strings.TrimSpace(viper.GetString("memory.embedding.ollama_model"))
		if legacyModel != "" && legacyStyle == "ollama" && legacyBase != "" {
			out = append(out, ProviderConfig{
				Type:     "ollama",
				BaseURL:  legacyBase,
				Model:    legacyModel,
				Priority: 2,
			})
		}
	}

	sortByPriority(out)
	return out
}

func LoadHybridConfig() HybridConfig {
	_ = ensureViper()
	cfg := HybridConfig{
		Enabled:       true,
		VectorWeight:  0.7,
		KeywordWeight: 0.3,
	}
	if viper.IsSet("memory.search.hybrid_enabled") {
		cfg.Enabled = viper.GetBool("memory.search.hybrid_enabled")
	}
	if w := viper.GetFloat64("memory.search.vector_weight"); w > 0 {
		cfg.VectorWeight = w
	}
	if w := viper.GetFloat64("memory.search.keyword_weight"); w > 0 {
		cfg.KeywordWeight = w
	}
	return cfg
}

// LoadEnhanceConfig 混合 + rerank + graph 一站式配置（供 API 检索）。
func LoadEnhanceConfig() (HybridConfig, RerankConfig, GraphConfig) {
	_ = ensureViper()
	hc := LoadHybridConfig()
	rc := RerankConfig{Enabled: true, TopK: 24, MMRLambda: 0.7}
	gc := GraphConfig{Enabled: true, Hops: 1, Boost: 0.35, MaxExpand: 6}
	if viper.IsSet("memory.search.rerank_enabled") {
		rc.Enabled = viper.GetBool("memory.search.rerank_enabled")
	}
	if k := viper.GetInt("memory.search.rerank_top_k"); k > 0 {
		rc.TopK = k
	}
	if l := viper.GetFloat64("memory.search.rerank_mmr_lambda"); l > 0 {
		rc.MMRLambda = l
	}
	if viper.IsSet("memory.search.graph_enabled") {
		gc.Enabled = viper.GetBool("memory.search.graph_enabled")
	}
	if h := viper.GetInt("memory.search.graph_hops"); h > 0 {
		gc.Hops = h
	}
	if b := viper.GetFloat64("memory.search.graph_boost"); b > 0 {
		gc.Boost = b
	}
	if m := viper.GetInt("memory.search.graph_max_expand"); m > 0 {
		gc.MaxExpand = m
	}
	return hc, rc, gc
}

func mapToProvider(m map[string]any) ProviderConfig {
	getStr := func(k string) string {
		v, _ := m[k].(string)
		return strings.TrimSpace(v)
	}
	pri := 10
	if v, ok := m["priority"].(int); ok {
		pri = v
	} else if v, ok := m["priority"].(float64); ok {
		pri = int(v)
	}
	pc := ProviderConfig{
		Type:     strings.ToLower(getStr("type")),
		BaseURL:  getStr("base_url"),
		APIKey:   getStr("api_key"),
		Model:    getStr("model"),
		Priority: pri,
	}
	if pc.APIKey == "" {
		if env := getStr("api_key_env"); env != "" {
			pc.APIKey = strings.TrimSpace(os.Getenv(env))
		}
	}
	return pc
}

func sortByPriority(list []ProviderConfig) {
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].Priority < list[i].Priority {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
}

var viperReady bool

func ensureViper() error {
	if viperReady {
		return nil
	}
	v := viper.GetViper()
	if v.ConfigFileUsed() != "" {
		viperReady = true
		return nil
	}
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()
	viperReady = true
	return nil
}
