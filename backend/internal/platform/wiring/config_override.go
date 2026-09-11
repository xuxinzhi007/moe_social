package runserver

import (
	"strings"

	"backend/internal/platform/apiconfig"
	"backend/pkg/conf"
	"backend/utils"
)

// ApplyUnifiedConfigOverrides 从 backend/config/config.yaml 合并 llm、RPC、鉴权等配置。
func ApplyUnifiedConfigOverrides(c *apiconfig.Config) {
	// 序3：llm_inference 段改走 pkg/conf。此前这里自己开一个 viper、自己抄一遍
	// MOE_LLM_* 四个环境变量的优先级（与 moeconfig.InferenceFromViper 逐行重复），
	// 且读不到文件时会连带跳过下面所有覆盖（见 §21.3）。现在 env 覆盖表只有
	// pkg/conf/derive.go 一处，本文件也不再硬编码 searchDirs。
	// 副作用：回退链多了 ollama.* 一级，而 config.yaml 里该段整段被注释，恒为空值。
	//
	// 「仅当值非空/为正才覆盖」的语义必须保留：c 来自 api/etc/moe.yaml 片段，
	// 片段里的值要在 config.yaml 未设置时存活。
	inf := conf.ResolveInference()
	if inf.BaseURL != "" {
		c.LLMInference.BaseUrl = inf.BaseURL
	}
	if inf.APIStyle != "" {
		c.LLMInference.ApiStyle = inf.APIStyle
	}
	if inf.TimeoutSeconds > 0 {
		c.LLMInference.TimeoutSeconds = inf.TimeoutSeconds
	}
	if inf.MemoryModel != "" {
		c.LLMInference.MemoryModel = inf.MemoryModel
	}
	if inf.APIKey != "" {
		c.LLMInference.ApiKey = inf.APIKey
	}

	// local_models 段改走 pkg/conf：此前 v.UnmarshalKey 解到只有 json/yaml tag 的
	// apiconfig.LocalModelCatalogEntry，而 mapstructure 默认按字段名匹配，size_bytes 与
	// parameters_b 因下划线对不上而静默丢值（sha256 这类单词键反而能过）。
	// 这也是全仓唯一一处拿 apiconfig 结构当 mapstructure 解码目标的地方，改掉之后
	// 「apiconfig 41 json / 0 mapstructure」不再构成隐患。
	lm := conf.Get().LocalModels
	if dir := strings.TrimSpace(lm.StorageDir); dir != "" {
		c.LocalModels.StorageDir = dir
	}
	if len(lm.Catalog) > 0 {
		c.LocalModels.Catalog = localModelCatalog(lm.Catalog)
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

// localModelCatalog 把 pkg/conf 的清单转成 API 片段的传输形状。
func localModelCatalog(in []conf.LocalModelCatalogEntry) []apiconfig.LocalModelCatalogEntry {
	out := make([]apiconfig.LocalModelCatalogEntry, 0, len(in))
	for _, e := range in {
		out = append(out, apiconfig.LocalModelCatalogEntry{
			Id:          e.ID,
			Name:        e.Name,
			Filename:    e.Filename,
			SizeBytes:   e.SizeBytes,
			Sha256:      e.SHA256,
			Description: e.Description,
			ParametersB: e.ParametersB,
			Recommended: e.Recommended,
		})
	}
	return out
}
