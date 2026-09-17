package core

import "strings"

// CapabilityTier 模型能力档位（与具体 GGUF 名称解耦）。
type CapabilityTier string

const (
	TierS0 CapabilityTier = "s0"
	TierS1 CapabilityTier = "s1"
	TierS2 CapabilityTier = "s2" // 默认：7B 本机
	TierS3 CapabilityTier = "s3"
)

// DefaultTier 未配置 Agent 时的默认档位（7B）。
const DefaultTier = TierS2

// ParseTier 规范化档位字符串。
func ParseTier(raw string) CapabilityTier {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "s0", "tier_s0":
		return TierS0
	case "s1", "tier_s1":
		return TierS1
	case "s3", "tier_s3":
		return TierS3
	default:
		return TierS2
	}
}

// AllowsTool 判断档位是否允许调用某工具。
//
// 这里列出的名字必须与 `pkg/moe/tools/registry.go` 的注册表保持一致：
// 两边分叉时不会报错，请求会先通过这道档位闸、再在 `Executor.Execute` 的 default
// 分支以「未知工具」失败 —— 失败原因被归到档位之外，排查时会往错的方向找。
// memory_search / memory_get / memory_save 曾长期留在这里，而注册表早就没有它们了。
func (t CapabilityTier) AllowsTool(tool string) bool {
	name := strings.TrimSpace(tool)
	switch t {
	case TierS0:
		return false
	case TierS1:
		return name == "post_search" || name == "post_get"
	case TierS3:
		return true
	default: // S2：注册表全集
		return name == "post_search" || name == "post_get" || name == "post_create" ||
			name == "brain_refine_episode" || name == "brain_curate_memories"
	}
}
