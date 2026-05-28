package runtime

import "strings"

// PhaseID 与管理台 brainPipelinePhases 对齐。
type PhaseID string

const (
	PhaseLoad     PhaseID = "load"
	PhaseMemory   PhaseID = "memory"
	PhasePrep     PhaseID = "prep"
	PhaseGenerate PhaseID = "generate"
	PhaseFinalize PhaseID = "finalize"
	PhasePublish  PhaseID = "publish"
)

// PhaseIDFromStepKey 将流水线 step key 映射为阶段 id。
func PhaseIDFromStepKey(key string) string {
	k := strings.TrimSpace(strings.ToLower(key))
	switch {
	case k == "load_runtime":
		return string(PhaseLoad)
	case k == "gather_memory" || strings.HasPrefix(k, "topic_"):
		return string(PhaseMemory)
	case k == "resolve_model" || k == "assemble_prompt":
		return string(PhasePrep)
	case strings.HasPrefix(k, "gen_attempt") || k == "generate":
		return string(PhaseGenerate)
	case k == "generate_finalize":
		return string(PhaseFinalize)
	case k == "post_create" || k == "record_episode":
		return string(PhasePublish)
	default:
		if k != "" {
			return string(PhasePrep)
		}
		return ""
	}
}
