package admingw

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

// KratosHTTPClient 调用纯 Kratos 试点 Admin HTTP（:19032）。
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
			Timeout: 60 * time.Second,
		},
	}
}

func (c *KratosHTTPClient) enabled() bool {
	return c != nil && c.baseURL != ""
}

func (c *KratosHTTPClient) AdminListAiChatSessions(ctx context.Context, in *super.AdminListAiChatSessionsReq) (*super.AdminListAiChatSessionsResp, error) {
	if in == nil {
		in = &super.AdminListAiChatSessionsReq{}
	}
	q := url.Values{}
	if in.GetPage() > 0 {
		q.Set("page", fmt.Sprintf("%d", in.GetPage()))
	}
	if in.GetPageSize() > 0 {
		q.Set("page_size", fmt.Sprintf("%d", in.GetPageSize()))
	}
	setQuery(q, "user_id", in.GetUserId())
	setQuery(q, "session_id", in.GetSessionId())
	setQuery(q, "from", in.GetFrom())
	setQuery(q, "to", in.GetTo())
	var resp types.AdminListAiChatSessionsResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/ai/chat/sessions?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http ai chat sessions: %s", resp.Message)
	}
	return typesAiChatSessionsToSuper(resp.Data), nil
}

func (c *KratosHTTPClient) AdminListAiChatMessages(ctx context.Context, in *super.AdminListAiChatMessagesReq) (*super.AdminListAiChatMessagesResp, error) {
	if in == nil {
		in = &super.AdminListAiChatMessagesReq{}
	}
	q := url.Values{}
	if in.GetPage() > 0 {
		q.Set("page", fmt.Sprintf("%d", in.GetPage()))
	}
	if in.GetPageSize() > 0 {
		q.Set("page_size", fmt.Sprintf("%d", in.GetPageSize()))
	}
	setQuery(q, "user_id", in.GetUserId())
	setQuery(q, "session_id", in.GetSessionId())
	setQuery(q, "role", in.GetRole())
	setQuery(q, "keyword", in.GetKeyword())
	setQuery(q, "from", in.GetFrom())
	setQuery(q, "to", in.GetTo())
	var resp types.AdminListAiChatMessagesResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/ai/chat/messages?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http ai chat messages: %s", resp.Message)
	}
	return typesAiChatMessagesToSuper(resp.Data), nil
}

func (c *KratosHTTPClient) AdminExportAiChatMessages(ctx context.Context, in *super.AdminExportAiChatMessagesReq) (*super.AdminExportAiChatMessagesResp, error) {
	if in == nil {
		in = &super.AdminExportAiChatMessagesReq{}
	}
	q := url.Values{}
	setQuery(q, "user_id", in.GetUserId())
	setQuery(q, "session_id", in.GetSessionId())
	setQuery(q, "role", in.GetRole())
	setQuery(q, "keyword", in.GetKeyword())
	setQuery(q, "from", in.GetFrom())
	setQuery(q, "to", in.GetTo())
	if in.GetLimit() > 0 {
		q.Set("limit", fmt.Sprintf("%d", in.GetLimit()))
	}
	var resp types.AdminExportAiChatMessagesResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/ai/chat/messages/export?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http export ai chat: %s", resp.Message)
	}
	return &super.AdminExportAiChatMessagesResp{
		Csv: resp.Data.Csv, RowCount: int32(resp.Data.RowCount), Truncated: resp.Data.Truncated,
	}, nil
}

func (c *KratosHTTPClient) AdminAnalyticsOverview(ctx context.Context, _ *super.AdminGetMemoryStatsReq) (*super.AdminAnalyticsOverviewResp, error) {
	var resp types.AdminAnalyticsOverviewResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/analytics/overview", &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http analytics overview: %s", resp.Message)
	}
	return typesAnalyticsOverviewToSuper(resp.Data), nil
}

func (c *KratosHTTPClient) AdminListTopicTags(ctx context.Context, in *super.AdminListTopicTagsReq) (*super.AdminListTopicTagsResp, error) {
	if in == nil {
		in = &super.AdminListTopicTagsReq{}
	}
	q := url.Values{}
	if in.GetPage() > 0 {
		q.Set("page", fmt.Sprintf("%d", in.GetPage()))
	}
	if in.GetPageSize() > 0 {
		q.Set("page_size", fmt.Sprintf("%d", in.GetPageSize()))
	}
	setQuery(q, "keyword", in.GetKeyword())
	var resp types.AdminListTopicTagsResp
	if err := c.getJSON(ctx, c.baseURL+"/api/admin/topic-tags?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, fmt.Errorf("kratos http topic tags: %s", resp.Message)
	}
	return typesTopicTagsToSuper(resp.Data), nil
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
		return fmt.Errorf("kratos http %s: status %d", rawURL, res.StatusCode)
	}
	if err := json.Unmarshal(body, dest); err != nil {
		return fmt.Errorf("kratos http decode %s: %w", rawURL, err)
	}
	return nil
}

func setQuery(q url.Values, key, val string) {
	if strings.TrimSpace(val) != "" {
		q.Set(key, val)
	}
}
