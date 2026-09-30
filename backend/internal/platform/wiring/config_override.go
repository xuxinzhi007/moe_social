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

	// Agora 逐键区分缺失与显式清空；不能用非空判断使旧凭证复活。
	agora := conf.Get().Agora
	if conf.IsSet("agora.app_id") {
		c.Agora.AppId = strings.TrimSpace(agora.AppID)
	}
	if conf.IsSet("agora.app_certificate") {
		c.Agora.AppCertificate = strings.TrimSpace(agora.AppCertificate)
	}
	if u := conf.ClientPublicBaseURL(); u != "" {
		c.ClientPublicApiBaseUrl = u
	}
	img := conf.Get().Image
	if d := strings.TrimSpace(img.LocalDir); d != "" {
		c.Image.LocalDir = d
	}
	if u := conf.ImagePublicBaseURL(); u != "" {
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
	// 密钥只取文件值：MOE_QINIU_* 由 biz/media/store_qiniu.go 兜底。
	qn := img.Qiniu
	if ak := strings.TrimSpace(qn.AccessKey); ak != "" {
		c.Image.Qiniu.AccessKey = ak
	}
	if sk := strings.TrimSpace(qn.SecretKey); sk != "" {
		c.Image.Qiniu.SecretKey = sk
	}
	if b := strings.TrimSpace(qn.Bucket); b != "" {
		c.Image.Qiniu.Bucket = b
	}
	if d := strings.TrimSpace(qn.CDNDomain); d != "" {
		c.Image.Qiniu.CDNDomain = d
	}
	if r := strings.TrimSpace(qn.Region); r != "" {
		c.Image.Qiniu.Region = r
	}
	if p := strings.TrimSpace(qn.Prefix); p != "" {
		c.Image.Qiniu.Prefix = p
	}
	if conf.IsSet("image.qiniu.private") {
		c.Image.Qiniu.Private = qn.Private
	}
	if conf.IsSet("image.qiniu.proxy_via_api") {
		c.Image.Qiniu.ProxyViaAPI = qn.ProxyViaAPI
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
