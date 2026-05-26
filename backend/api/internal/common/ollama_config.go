package common

// ResolveOllamaBaseURL 已废弃，请使用 ResolveInferenceBaseURL。
func ResolveOllamaBaseURL(configured string) (string, error) {
	return ResolveInferenceBaseURL(configured)
}
