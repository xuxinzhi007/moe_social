package config

// Config API 片段（api/etc/moe.yaml）；运行时值以 config/config.yaml 为准。
type Config struct {
	Name    string `json:"Name" yaml:"Name"`
	Host    string `json:"Host" yaml:"Host"`
	Port    int    `json:"Port" yaml:"Port"`
	Timeout int64  `json:"Timeout" yaml:"Timeout"`

	Auth struct {
		AccessSecret string
		AccessExpire int64
	} `json:"Auth" yaml:"Auth"`

	LLMInference LLMInferenceConf `json:"LLMInference" yaml:"LLMInference"`
	LocalModels  LocalModelsConf  `json:"LocalModels" yaml:"LocalModels"`
	Agora        AgoraConf        `json:"Agora" yaml:"Agora"`
	Image        ImageConf        `json:"Image" yaml:"Image"`

	// ClientPublicApiBaseUrl 由 wiring 从 config/config.yaml 写入；不参与 api/etc 解析。
	ClientPublicApiBaseUrl string `json:"-" yaml:"-"`
}

type LocalModelCatalogEntry struct {
	Id          string  `json:"Id" yaml:"id"`
	Name        string  `json:"Name" yaml:"name"`
	Filename    string  `json:"Filename" yaml:"filename"`
	SizeBytes   int64   `json:"SizeBytes" yaml:"size_bytes"`
	Sha256      string  `json:"Sha256" yaml:"sha256"`
	Description string  `json:"Description" yaml:"description"`
	ParametersB float64 `json:"ParametersB" yaml:"parameters_b"`
	Recommended bool    `json:"Recommended" yaml:"recommended"`
}

type LocalModelsConf struct {
	StorageDir string                   `json:"StorageDir" yaml:"storage_dir"`
	Catalog    []LocalModelCatalogEntry `json:"Catalog" yaml:"catalog"`
}

type LLMInferenceConf struct {
	BaseUrl               string `json:"BaseUrl" yaml:"BaseUrl"`
	ApiStyle              string `json:"ApiStyle" yaml:"ApiStyle"`
	TimeoutSeconds        int    `json:"TimeoutSeconds" yaml:"TimeoutSeconds"`
	MemoryModel           string `json:"MemoryModel" yaml:"MemoryModel"`
	MemorySummaryPrompt   string `json:"MemorySummaryPrompt" yaml:"MemorySummaryPrompt"`
	MemoryExtractPrompt   string `json:"MemoryExtractPrompt" yaml:"MemoryExtractPrompt"`
	ApiKey                string `json:"ApiKey" yaml:"ApiKey"`
}

type AgoraConf struct {
	AppId          string `json:"AppId" yaml:"AppId"`
	AppCertificate string `json:"AppCertificate" yaml:"AppCertificate"`
}

type ImageConf struct {
	LocalDir      string `json:"LocalDir" yaml:"LocalDir"`
	PublicBaseUrl string `json:"PublicBaseUrl" yaml:"PublicBaseUrl"`
	MaxBytes      int64  `json:"MaxBytes" yaml:"MaxBytes"`
}

