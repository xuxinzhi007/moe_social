package runserver

import (
	"os"
	"strings"

	"backend/internal/platform/apiconfig"
	"backend/utils"

	"github.com/spf13/viper"
)

// ApplyUnifiedConfigOverrides 从 backend/config/config.yaml 合并 llm、RPC、鉴权等配置。
func ApplyUnifiedConfigOverrides(c *apiconfig.Config) {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return
	}

	if base := v.GetString("llm_inference.base_url"); base != "" {
		c.LLMInference.BaseUrl = base
	} else if base := v.GetString("ollama.base_url"); base != "" {
		c.LLMInference.BaseUrl = base
	}
	if style := strings.TrimSpace(v.GetString("llm_inference.api_style")); style != "" {
		c.LLMInference.ApiStyle = style
	} else if style := strings.TrimSpace(v.GetString("ollama.api_style")); style != "" {
		c.LLMInference.ApiStyle = style
	}
	if ts := v.GetInt("llm_inference.timeout_seconds"); ts > 0 {
		c.LLMInference.TimeoutSeconds = ts
	} else if ts := v.GetInt("ollama.timeout_seconds"); ts > 0 {
		c.LLMInference.TimeoutSeconds = ts
	}
	if m := strings.TrimSpace(v.GetString("llm_inference.memory_model")); m != "" {
		c.LLMInference.MemoryModel = m
	} else if m := strings.TrimSpace(v.GetString("ollama.memory_model")); m != "" {
		c.LLMInference.MemoryModel = m
	}
	if apiKey := strings.TrimSpace(os.Getenv("MOE_LLM_API_KEY")); apiKey != "" {
		c.LLMInference.ApiKey = apiKey
	} else if apiKey := strings.TrimSpace(v.GetString("llm_inference.api_key")); apiKey != "" {
		c.LLMInference.ApiKey = apiKey
	} else if apiKey := strings.TrimSpace(v.GetString("ollama.api_key")); apiKey != "" {
		c.LLMInference.ApiKey = apiKey
	}
	if dir := v.GetString("local_models.storage_dir"); dir != "" {
		c.LocalModels.StorageDir = dir
	}
	if v.IsSet("local_models.catalog") {
		var entries []apiconfig.LocalModelCatalogEntry
		if err := v.UnmarshalKey("local_models.catalog", &entries); err == nil && len(entries) > 0 {
			c.LocalModels.Catalog = entries
		}
	}
	if timeoutMs := v.GetInt64("api.timeout_ms"); timeoutMs > 0 {
		c.Timeout = timeoutMs
	}
	if u := v.GetString("app_client.public_api_base_url"); u != "" {
		c.ClientPublicApiBaseUrl = u
	}
	if d := firstNonEmptyString(v, "image.local_dir", "image.localdir", "Image.LocalDir"); d != "" {
		c.Image.LocalDir = d
	}
	if u := firstNonEmptyString(v, "image.public_base_url", "image.publicbaseurl", "Image.PublicBaseUrl"); u != "" {
		c.Image.PublicBaseUrl = u
	}
	if n := firstPositiveInt64(v, "image.max_bytes", "image.maxbytes", "Image.MaxBytes"); n > 0 {
		c.Image.MaxBytes = n
	}
	if d := firstNonEmptyString(v, "image.driver", "Image.Driver"); d != "" {
		c.Image.Driver = d
	}
	if ep := firstNonEmptyString(v, "image.oss.endpoint", "Image.OSS.Endpoint"); ep != "" {
		c.Image.OSS.Endpoint = ep
	}
	if b := firstNonEmptyString(v, "image.oss.bucket", "Image.OSS.Bucket"); b != "" {
		c.Image.OSS.Bucket = b
	}
	if ak := firstNonEmptyString(v, "image.oss.access_key_id", "Image.OSS.AccessKeyID"); ak != "" {
		c.Image.OSS.AccessKeyID = ak
	}
	if sk := firstNonEmptyString(v, "image.oss.access_key_secret", "Image.OSS.AccessKeySecret"); sk != "" {
		c.Image.OSS.AccessKeySecret = sk
	}
	if p := firstNonEmptyString(v, "image.oss.prefix", "Image.OSS.Prefix"); p != "" {
		c.Image.OSS.Prefix = p
	}
	if u := firstNonEmptyString(v, "image.oss.public_base_url", "Image.OSS.PublicBaseUrl"); u != "" {
		c.Image.OSS.PublicBaseUrl = u
	}
	if r := firstNonEmptyString(v, "image.oss.region", "Image.OSS.Region"); r != "" {
		c.Image.OSS.Region = r
	}
	if v.IsSet("image.oss.proxy_via_api") {
		c.Image.OSS.ProxyViaAPI = v.GetBool("image.oss.proxy_via_api")
	} else if v.IsSet("Image.OSS.ProxyViaAPI") {
		c.Image.OSS.ProxyViaAPI = v.GetBool("Image.OSS.ProxyViaAPI")
	}
	if secret := strings.TrimSpace(os.Getenv("MOE_AUTH_ACCESS_SECRET")); secret != "" {
		c.Auth.AccessSecret = secret
	} else if secret := firstNonEmptyString(v, "auth.access_secret"); secret != "" {
		c.Auth.AccessSecret = secret
	}
	if exp := v.GetInt64("auth.access_expire_seconds"); exp > 0 {
		c.Auth.AccessExpire = exp
	}
	if secret := firstNonEmptyString(v, "admin.jwt_secret"); secret != "" {
		hours := v.GetInt64("admin.token_expire_hours")
		if hours <= 0 {
			hours = 24
		}
		_ = utils.ConfigureAdminJWT(secret, hours)
	}
}

func firstNonEmptyString(v *viper.Viper, keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(v.GetString(key)); value != "" {
			return value
		}
	}
	return ""
}

func firstPositiveInt64(v *viper.Viper, keys ...string) int64 {
	for _, key := range keys {
		if value := v.GetInt64(key); value > 0 {
			return value
		}
	}
	return 0
}
