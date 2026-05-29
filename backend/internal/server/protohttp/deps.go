package protohttp

import (
	"backend/internal/apilegacy/config"
)

// Option 可选依赖（P1 Moe legacy HTTP）。
type Option func(*Server)

// WithInferenceConfig 注入推理配置（GET /api/admin/moe/inference/status）。
func WithInferenceConfig(cfg config.LLMInferenceConf) Option {
	return func(s *Server) {
		s.inferenceCfg = cfg
	}
}
