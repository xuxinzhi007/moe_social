package runserver

import (
	"os"
	"strings"

	"backend/internal/platform/apiconfig"
	"backend/pkg/conf"
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

	if base := strings.TrimSpace(os.Getenv("MOE_LLM_BASE_URL")); base != "" {
		c.LLMInference.BaseUrl = base
	} else if base := v.GetString("llm_inference.base_url"); base != "" {
		c.LLMInference.BaseUrl = base
	}
	if style := strings.TrimSpace(os.Getenv("MOE_LLM_API_STYLE")); style != "" {
		c.LLMInference.ApiStyle = style
	} else if style := strings.TrimSpace(v.GetString("llm_inference.api_style")); style != "" {
		c.LLMInference.ApiStyle = style
	}
	if ts := v.GetInt("llm_inference.timeout_seconds"); ts > 0 {
		c.LLMInference.TimeoutSeconds = ts
	}
	if m := strings.TrimSpace(os.Getenv("MOE_LLM_MODEL")); m != "" {
		c.LLMInference.MemoryModel = m
	} else if m := strings.TrimSpace(v.GetString("llm_inference.memory_model")); m != "" {
		c.LLMInference.MemoryModel = m
	}
	if apiKey := strings.TrimSpace(os.Getenv("MOE_LLM_API_KEY")); apiKey != "" {
		c.LLMInference.ApiKey = apiKey
	} else if apiKey := strings.TrimSpace(v.GetString("llm_inference.api_key")); apiKey != "" {
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
	// —— 序2：以下各段改由 pkg/conf 读取。
	// 「仅当值非空/为正才覆盖」的语义必须保留：c 来自 api/etc/moe.yaml 片段，
	// 片段里的值（如 Image.MaxBytes、Auth.AccessExpire）要在 config.yaml 未设置时存活。
	if u := conf.Get().AppClient.PublicAPIBaseURL; u != "" {
		c.ClientPublicApiBaseUrl = u
	}
	img := conf.Get().Image
	if d := strings.TrimSpace(img.LocalDir); d != "" {
		c.Image.LocalDir = d
	}
	if u := strings.TrimSpace(img.PublicBaseURL); u != "" {
		c.Image.PublicBaseUrl = u
	}
	if n := img.MaxBytes; n > 0 {
		c.Image.MaxBytes = n
	}
	if d := strings.TrimSpace(img.Driver); d != "" {
		c.Image.Driver = d
	}
	oss := img.OSS
	if ep := strings.TrimSpace(oss.Endpoint); ep != "" {
		c.Image.OSS.Endpoint = ep
	}
	if b := strings.TrimSpace(oss.Bucket); b != "" {
		c.Image.OSS.Bucket = b
	}
	// 密钥只取文件值：MOE_OSS_* 兜底由真实消费方 biz/media/store_oss.go:29-34 负责，
	// 这里再兜一遍是重复的，且会让本层平白多出环境变量影响。
	if ak := strings.TrimSpace(oss.AccessKeyID); ak != "" {
		c.Image.OSS.AccessKeyID = ak
	}
	if sk := strings.TrimSpace(oss.AccessKeySecret); sk != "" {
		c.Image.OSS.AccessKeySecret = sk
	}
	if p := strings.TrimSpace(oss.Prefix); p != "" {
		c.Image.OSS.Prefix = p
	}
	if u := strings.TrimSpace(oss.PublicBaseURL); u != "" {
		c.Image.OSS.PublicBaseUrl = u
	}
	if r := strings.TrimSpace(oss.Region); r != "" {
		c.Image.OSS.Region = r
	}
	if conf.IsSet("image.oss.proxy_via_api") {
		c.Image.OSS.ProxyViaAPI = oss.ProxyViaAPI
	}
	if secret := conf.AuthAccessSecret(); secret != "" {
		c.Auth.AccessSecret = secret
	}
	if exp := conf.Get().Auth.AccessExpireSeconds; exp > 0 {
		c.Auth.AccessExpire = exp
	}
	// AdminJWT() 认 MOE_ADMIN_JWT_SECRET；此前这里只读文件，那个环境变量自
	// LoadAdminJWTFromViper 失去调用方起就是一条无人读取的死通道（见 §19.2）。
	if secret, hours := conf.AdminJWT(); secret != "" {
		_ = utils.ConfigureAdminJWT(secret, hours)
	}
}
