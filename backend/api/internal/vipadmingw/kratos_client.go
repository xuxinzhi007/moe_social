package vipadmingw

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"
	"backend/model"
)

// KratosHTTPClient 调用纯 Kratos 试点 VIP HTTP（cmd/moe-kratos :19032）。
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

// ListPlans 对应 GET /api/admin/vip/plans（与 go-zero 响应形状一致）。
func (c *KratosHTTPClient) ListPlans(ctx context.Context, f vipbiz.ListPlansFilter) ([]model.VipPlan, int64, error) {
	q := url.Values{}
	if f.Page > 0 {
		q.Set("page", strconv.Itoa(f.Page))
	}
	if f.PageSize > 0 {
		q.Set("page_size", strconv.Itoa(f.PageSize))
	}
	if kw := strings.TrimSpace(f.Keyword); kw != "" {
		q.Set("keyword", kw)
	}
	if f.IncludeDeleted {
		q.Set("include_deleted", "true")
	}
	raw := c.baseURL + "/api/admin/vip/plans"
	if enc := q.Encode(); enc != "" {
		raw += "?" + enc
	}
	var resp types.AdminListVipPlansResp
	if err := c.getJSON(ctx, raw, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Code != 0 || !resp.Success {
		return nil, 0, fmt.Errorf("kratos http list vip plans: %s", resp.Message)
	}
	out := make([]model.VipPlan, 0, len(resp.Data.Items))
	for _, item := range resp.Data.Items {
		out = append(out, vipPlanTypesToModel(item))
	}
	return out, int64(resp.Data.Total), nil
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

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
