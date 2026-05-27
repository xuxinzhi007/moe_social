package llminference

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path"
	"strings"
)

// PickResult 从推理服务返回的模型列表中解析实际使用的模型 ID。
type PickResult struct {
	ModelID       string
	Preferred     string
	AutoDiscovered bool
}

// PickModel 在 available 中选取与 preferred 最匹配的模型；无精确匹配时自动回退。
func PickModel(preferred string, available []string) PickResult {
	preferred = strings.TrimSpace(preferred)
	clean := dedupeNonEmpty(available)
	if len(clean) == 0 {
		return PickResult{ModelID: preferred, Preferred: preferred}
	}
	if preferred == "" {
		return PickResult{ModelID: clean[0], Preferred: "", AutoDiscovered: true}
	}
	lowerPref := strings.ToLower(preferred)
	for _, id := range clean {
		if strings.EqualFold(id, preferred) {
			return PickResult{ModelID: id, Preferred: preferred}
		}
	}
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
	// qwen2 vs qwen2.5-0.5b-instruct：按主版本前缀
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

// ListModelIDs 拉取 OpenAI 兼容 /v1/models 的模型 ID 列表。
func ListModelIDs(ctx context.Context, cfg Config) ([]string, error) {
	if !cfg.Ready() {
		return nil, nil
	}
	client := &http.Client{Timeout: cfg.Timeout}
	return listOpenAIModelIDs(ctx, client, cfg.BaseURL)
}

func listOpenAIModelIDs(ctx context.Context, client *http.Client, baseURL string) ([]string, error) {
	root := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	apiRoot := root
	if !strings.HasSuffix(apiRoot, "/v1") {
		apiRoot += "/v1"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiRoot+"/models", nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("list models failed: %d %s", resp.StatusCode, string(b))
	}
	var parsed struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(parsed.Data))
	for _, m := range parsed.Data {
		if id := strings.TrimSpace(m.ID); id != "" {
			out = append(out, id)
		}
	}
	return out, nil
}
