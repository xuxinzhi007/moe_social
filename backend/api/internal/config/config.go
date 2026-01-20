package config

import (
	"github.com/zeromicro/go-zero/rest"
	"github.com/zeromicro/go-zero/zrpc"
)

type Config struct {
	rest.RestConf
	// RPC服务配置
	SuperRpc zrpc.RpcClientConf `json:"SuperRpc" yaml:"SuperRpc"`

	// Ollama 配置（用于 /api/llm/*）
	Ollama OllamaConf `json:"Ollama" yaml:"Ollama"`
}

type OllamaConf struct {
	// BaseUrl 例如：http://127.0.0.1:11434
	BaseUrl string `json:"BaseUrl" yaml:"BaseUrl"`
	// TimeoutSeconds 请求 Ollama 的超时（秒），建议比反代/客户端超时更长
	TimeoutSeconds int `json:"TimeoutSeconds" yaml:"TimeoutSeconds"`
	// MemoryModel 用于总结和记忆提取的模型，不配置则默认使用聊天模型
	MemoryModel string `json:"MemoryModel" yaml:"MemoryModel"`
	// MemorySummaryPrompt 总结对话时使用的系统提示词
	MemorySummaryPrompt string `json:"MemorySummaryPrompt" yaml:"MemorySummaryPrompt"`
	// MemoryExtractPrompt 记忆提取时使用的系统提示词
	MemoryExtractPrompt string `json:"MemoryExtractPrompt" yaml:"MemoryExtractPrompt"`
}
