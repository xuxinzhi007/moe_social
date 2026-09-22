package llminference

import (
	"context"
	"net/http"
	"path"
	"regexp"
	"strings"
)

// PickResult 从推理服务返回的模型列表中解析实际使用的模型 ID。
type PickResult struct {
	ModelID        string
	Preferred      string
	AutoDiscovered bool
}

// PickModel 在 available 中选取与 preferred 最匹配的模型；无精确匹配时自动回退。
func PickModel(preferred string, available []string) PickResult {
	preferred = strings.TrimSpace(preferred)
	all := dedupeNonEmpty(available)
	for _, id := range all {
		if id == preferred || (!isManagedModel(id) && strings.EqualFold(id, preferred)) {
			return PickResult{ModelID: id, Preferred: preferred}
		}
	}
	// A managed name is usable only when explicitly specified, never by fuzzy
	// match or catalog ordering. Keep an explicit name even if tags is stale.
	if isManagedModel(preferred) {
		return PickResult{ModelID: preferred, Preferred: preferred}
	}
	clean := make([]string, 0, len(all))
	for _, id := range all {
		if !isManagedModel(id) {
			clean = append(clean, id)
		}
	}
	if len(clean) == 0 {
		return PickResult{ModelID: preferred, Preferred: preferred}
	}
	if preferred == "" {
		return PickResult{ModelID: clean[0], Preferred: "", AutoDiscovered: true}
	}
	lowerPref := strings.ToLower(preferred)
	for _, id := range clean {
		if modelIDMatches(id, lowerPref) {
			return PickResult{ModelID: id, Preferred: preferred, AutoDiscovered: true}
		}
	}
	return PickResult{ModelID: clean[0], Preferred: preferred, AutoDiscovered: true}
}

func modelIDMatches(modelID, lowerPreferred string) bool {
	lowerID := strings.ToLower(strings.TrimSpace(modelID))
	if lowerID == "" || lowerPreferred == "" {
		return false
	}
	if strings.Contains(lowerID, lowerPreferred) || strings.Contains(lowerPreferred, lowerID) {
		return true
	}
	base := strings.ToLower(path.Base(modelID))
	if base != lowerID && (strings.Contains(base, lowerPreferred) || strings.Contains(lowerPreferred, base)) {
		return true
	}
	if strings.HasPrefix(lowerID, lowerPreferred) || strings.HasPrefix(base, lowerPreferred) {
		return true
	}
	return false
}

func dedupeNonEmpty(in []string) []string {
	seen := make(map[string]struct{}, len(in))
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		key := strings.ToLower(s)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, s)
	}
	return out
}

// ListModelIDs is a protocol-aware alias of ListModels.
func ListModelIDs(ctx context.Context, cfg Config) ([]string, error) {
	return ListModels(ctx, cfg)
}

// ListModelNames is a protocol-aware alias of ListModels.
func ListModelNames(ctx context.Context, cfg Config) ([]string, error) {
	return ListModels(ctx, cfg)
}

func isManagedModel(name string) bool {
	return strings.HasPrefix(strings.ToLower(strings.TrimSpace(name)), "moe-user-")
}

// ModelInfo is native Ollama model metadata. Callers must authorize access.
type ModelInfo struct {
	System     string         `json:"system"`
	Modelfile  string         `json:"modelfile"`
	Template   string         `json:"template"`
	Parameters string         `json:"parameters"`
	Details    map[string]any `json:"details,omitempty"`
}

var (
	tripleSystemPattern = regexp.MustCompile(`(?s)SYSTEM\s+"""(.*?)"""`)
	quotedSystemPattern = regexp.MustCompile(`SYSTEM\s+"(.*?)"`)
)

// SystemPrompt extracts the model system prompt from native metadata.
func (m ModelInfo) SystemPrompt() string {
	if strings.TrimSpace(m.System) != "" {
		return m.System
	}
	if match := tripleSystemPattern.FindStringSubmatch(m.Modelfile); match != nil {
		return strings.TrimSpace(match[1])
	}
	if match := quotedSystemPattern.FindStringSubmatch(m.Modelfile); match != nil {
		return strings.TrimSpace(match[1])
	}
	return ""
}

func validateModelName(name string) error {
	if name == "" || len(name) > 512 || strings.TrimSpace(name) != name {
		return upstreamError("invalid model name", 0, false)
	}
	for _, r := range name {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("-_./:", r)) {
			return upstreamError("invalid model name", 0, false)
		}
	}
	for _, segment := range strings.Split(name, "/") {
		if segment == "" || segment == "." || segment == ".." {
			return upstreamError("invalid model name", 0, false)
		}
	}
	return nil
}

// ShowModel fetches native metadata without pulling or modifying the model.
func ShowModel(ctx context.Context, cfg Config, model string) (ModelInfo, error) {
	var info ModelInfo
	if err := validateModelName(model); err != nil {
		return info, err
	}
	err := requestJSON(ctx, cfg, http.MethodPost, "/api/show", "", map[string]string{"model": model}, &info, false)
	return info, err
}

// CreateModel derives a model from an already available base; it never auto-pulls.
// Only an explicit success response is considered a confirmed write.
func CreateModel(ctx context.Context, cfg Config, name, base, prompt string) error {
	if err := validateModelName(name); err != nil {
		return err
	}
	if err := validateModelName(base); err != nil {
		return err
	}
	var result struct {
		Status string `json:"status"`
	}
	body := map[string]any{"model": name, "from": base, "system": prompt, "stream": false}
	if err := requestJSON(ctx, cfg, http.MethodPost, "/api/create", "", body, &result, true); err != nil {
		return err
	}
	if result.Status != "success" {
		return upstreamError("model creation not confirmed", http.StatusOK, true)
	}
	return nil
}

// DeleteModel deletes an explicitly authorized native model.
func DeleteModel(ctx context.Context, cfg Config, name string) error {
	if err := validateModelName(name); err != nil {
		return err
	}
	return requestJSON(ctx, cfg, http.MethodDelete, "/api/delete", "", map[string]string{"model": name}, nil, true)
}
