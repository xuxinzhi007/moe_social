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
		base := strings.TrimSpace(ollamaBaseURL)
		if base == "" {
			base = strings.TrimSpace(viper.GetString("ollama.base_url"))
		}
		model := strings.TrimSpace(viper.GetString("memory.embedding.ollama_model"))
		if model == "" {
			model = "nomic-embed-text"
		}
		if base != "" {
			out = append(out, ProviderConfig{
				Type:     "ollama",
				BaseURL:  base,
				Model:    model,
				Priority: 1,
			})
		}
		oBase := strings.TrimSpace(viper.GetString("memory.embedding.openai_base_url"))
		oKey := strings.TrimSpace(viper.GetString("memory.embedding.openai_api_key"))
		if oKey == "" {
			oKey = strings.TrimSpace(os.Getenv("MOE_MEMORY_EMBED_API_KEY"))
		}
		oModel := strings.TrimSpace(viper.GetString("memory.embedding.openai_model"))
		if oModel == "" {
			oModel = "text-embedding-3-small"
		}
		if oBase != "" && oKey != "" {
			out = append(out, ProviderConfig{
				Type:     "openai_compatible",
				BaseURL:  oBase,
				APIKey:   oKey,
				Model:    oModel,
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
