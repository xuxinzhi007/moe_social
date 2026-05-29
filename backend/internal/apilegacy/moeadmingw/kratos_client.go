package moeadmingw

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"backend/internal/legacy/types"
	moebiz "backend/internal/biz/moe"
	"backend/model"
)

// KratosHTTPClient 调用纯 Kratos 试点 HTTP（cmd/moe-kratos :19032）。
type KratosHTTPClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewKratosHTTPClient baseURL 如 http://127.0.0.1:19032
func NewKratosHTTPClient(baseURL string) *KratosHTTPClient {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" {
		return nil
	}
	return &KratosHTTPClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *KratosHTTPClient) enabled() bool {
	return c != nil && c.baseURL != ""
}

func (c *KratosHTTPClient) ListRuntimes(ctx context.Context) ([]model.MoeAgentRuntime, error) {
	var resp types.AdminListMoeRuntimesResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/moe/runtimes", &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http list runtimes: %s", resp.Message)
	}
	out := make([]model.MoeAgentRuntime, 0, len(resp.Data.Items))
	for _, item := range resp.Data.Items {
		botUID, err := moebiz.ParseBotUserID(item.BotUserId)
		if err != nil {
			return nil, err
		}
		rt := model.MoeAgentRuntime{
			AgentKey:          item.AgentKey,
			DisplayName:       item.DisplayName,
			BotUserID:         botUID,
			CapabilityTier:    item.CapabilityTier,
			ModelName:         item.ModelName,
			ProviderProfileID: item.ProviderProfileId,
			ToolsEnabled:      item.ToolsEnabled,
			PostQuotaDaily:    item.PostQuotaDaily,
			PostsToday:        item.PostsToday,
			Enabled:           item.Enabled,
			LastPostID:        item.LastPostId,
			SystemPrompt:      item.SystemPrompt,
			PostRules:         item.PostRules,
			ForbiddenTags:     item.ForbiddenTags,
			PreferredTags:     item.PreferredTags,
			PostScheduleMode:  item.PostScheduleMode,
			ScheduleCron:      item.ScheduleCron,
		}
		if t := parseTimePtr(item.LastRunAt); t != nil {
			rt.LastRunAt = t
		}
		if t := parseTimePtr(item.NextRunAt); t != nil {
			rt.NextRunAt = t
		}
		out = append(out, rt)
	}
	return out, nil
}

func (c *KratosHTTPClient) GetBrainPipeline(ctx context.Context, agentKey string) (moebiz.PipelineSnapshot, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return moebiz.PipelineSnapshot{}, fmt.Errorf("agent_key is required")
	}
	u := c.baseURL + "/api/admin/moe/brain/pipeline?" + url.Values{"agent_key": {agentKey}}.Encode()
	var resp types.AdminGetMoeBrainPipelineResp
	if err := c.getJSON(ctx, u, &resp); err != nil {
		return moebiz.PipelineSnapshot{}, err
	}
	if resp.Code != 0 || !resp.Success {
		return moebiz.PipelineSnapshot{}, fmt.Errorf("kratos http brain pipeline: %s", resp.Message)
	}
	return pipelineFromTypesData(resp.Data), nil
}

func (c *KratosHTTPClient) getJSON(ctx context.Context, rawURL string, dest any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return err
	}
	res, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("kratos http %s: %w", rawURL, err)
	}
	defer res.Body.Close()
	body, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("kratos http %s: status %d body %s", rawURL, res.StatusCode, truncate(string(body), 200))
	}
	if err := json.Unmarshal(body, dest); err != nil {
		return fmt.Errorf("kratos http decode %s: %w", rawURL, err)
	}
	return nil
}

func parseTimePtr(s string) *time.Time {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	layouts := []string{"2006-01-02 15:04:05", time.RFC3339}
	for _, layout := range layouts {
		if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
			return &t
		}
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}

