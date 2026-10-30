package apiconfig

// Config API 片段（api/etc/moe.yaml）；运行时值以 config/config.yaml 为准。
type Config struct {
	Name string `json:"Name" yaml:"Name"`
	Host string `json:"Host" yaml:"Host"`
	Port int    `json:"Port" yaml:"Port"`

	Auth struct {
		AccessSecret string
		AccessExpire int64
	} `json:"Auth" yaml:"Auth"`

	LLMInference LLMInferenceConf `json:"LLMInference" yaml:"LLMInference"`
	Image        ImageConf        `json:"Image" yaml:"Image"`

	// ClientPublicApiBaseUrl 由 wiring 从 config/config.yaml 写入；不参与 api/etc 解析。
	ClientPublicApiBaseUrl string `json:"-" yaml:"-"`
}

// DefaultConfig 返回原 api/etc/moe.yaml 片段承载的基础缺省值（端口 :8888、JWT 5 天、
// 本地推理兜底、图片存储缺省目录与 1GB 上限）。运行时值随后由 ApplyUnifiedConfigOverrides 覆盖。
func DefaultConfig() Config {
	var c Config
	c.Name = "moe-social"
	c.Host = "0.0.0.0"
	c.Port = 8888
	c.Auth.AccessExpire = 432000
	c.LLMInference = LLMInferenceConf{
		BaseUrl:        "http://127.0.0.1:6633",
		ApiStyle:       "openai",
		TimeoutSeconds: 300,
	}
	c.Image = ImageConf{
		LocalDir: "/app/data/images",
		MaxBytes: 1073741824,
	}
	return c
}

type LLMInferenceConf struct {
	BaseUrl             string `json:"BaseUrl" yaml:"BaseUrl"`
	ApiStyle            string `json:"ApiStyle" yaml:"ApiStyle"`
	TimeoutSeconds      int    `json:"TimeoutSeconds" yaml:"TimeoutSeconds"`
	MemoryModel         string `json:"MemoryModel" yaml:"MemoryModel"`
	MemorySummaryPrompt string `json:"MemorySummaryPrompt" yaml:"MemorySummaryPrompt"`
	MemoryExtractPrompt string `json:"MemoryExtractPrompt" yaml:"MemoryExtractPrompt"`
	ApiKey              string `json:"ApiKey" yaml:"ApiKey"`
}

type ImageConf struct {
	LocalDir      string `json:"LocalDir" yaml:"LocalDir"`
	PublicBaseUrl string `json:"PublicBaseUrl" yaml:"PublicBaseUrl"`
	MaxBytes      int64  `json:"MaxBytes" yaml:"MaxBytes"`
	// Driver: local | oss | qiniu（空=local）
	Driver string     `json:"Driver" yaml:"Driver"`
	OSS    ImageOSS   `json:"OSS" yaml:"OSS"`
	Qiniu  ImageQiniu `json:"Qiniu" yaml:"Qiniu"`
}

// ImageQiniu 七牛对象存储。
type ImageQiniu struct {
	AccessKey   string `json:"AccessKey" yaml:"AccessKey"`
	SecretKey   string `json:"SecretKey" yaml:"SecretKey"`
	Bucket      string `json:"Bucket" yaml:"Bucket"`
	CDNDomain   string `json:"CDNDomain" yaml:"CDNDomain"`
	Region      string `json:"Region" yaml:"Region"`
	Prefix      string `json:"Prefix" yaml:"Prefix"`
	Private     bool   `json:"Private" yaml:"Private"`
	ProxyViaAPI bool   `json:"ProxyViaAPI" yaml:"ProxyViaAPI"`
}

// ImageOSS 阿里云对象存储。
type ImageOSS struct {
	Endpoint        string `json:"Endpoint" yaml:"Endpoint"`
	Bucket          string `json:"Bucket" yaml:"Bucket"`
	AccessKeyID     string `json:"AccessKeyID" yaml:"AccessKeyID"`
	AccessKeySecret string `json:"AccessKeySecret" yaml:"AccessKeySecret"`
	Prefix          string `json:"Prefix" yaml:"Prefix"`
	PublicBaseUrl   string `json:"PublicBaseUrl" yaml:"PublicBaseUrl"`
	Region          string `json:"Region" yaml:"Region"`
	ProxyViaAPI     bool   `json:"ProxyViaAPI" yaml:"ProxyViaAPI"`
}
