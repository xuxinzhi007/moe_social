package github

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Client calls GitHub REST API.
type Client struct {
	Owner    string
	Repo     string
	Token    string
	Workflow string
	HTTP     *http.Client
}

// NewClient creates a GitHub API client.
func NewClient(owner, repo, token, workflow string) *Client {
	return &Client{
		Owner:    owner,
		Repo:     repo,
		Token:    token,
		Workflow: workflow,
		HTTP:     &http.Client{Timeout: 30 * time.Second},
	}
}

// Enabled reports whether token is configured.
func (c *Client) Enabled() bool {
	return strings.TrimSpace(c.Token) != ""
}

// ReleaseInfo from GitHub releases/latest.
type ReleaseInfo struct {
	TagName     string `json:"tag_name"`
	Name        string `json:"name"`
	PublishedAt string `json:"published_at"`
	HTMLURL     string `json:"html_url"`
}

// LatestRelease fetches the latest release.
func (c *Client) LatestRelease(ctx context.Context) (*ReleaseInfo, error) {
	if !c.Enabled() {
		return nil, fmt.Errorf("github token not configured")
	}
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases/latest", c.Owner, c.Repo)
	var rel ReleaseInfo
	if err := c.getJSON(ctx, url, &rel); err != nil {
		return nil, err
	}
	return &rel, nil
}

// WorkflowRun summary.
type WorkflowRun struct {
	ID         int64  `json:"id"`
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
	HTMLURL    string `json:"html_url"`
	CreatedAt  string `json:"created_at"`
}

// ListWorkflowRuns returns recent runs for the configured workflow file.
func (c *Client) ListWorkflowRuns(ctx context.Context, perPage int) ([]WorkflowRun, error) {
	if !c.Enabled() {
		return nil, fmt.Errorf("github token not configured")
	}
	if perPage <= 0 {
		perPage = 5
	}
	wf := strings.TrimSpace(c.Workflow)
	if wf == "" {
		wf = "flutter-release.yml"
	}
	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/actions/workflows/%s/runs?per_page=%d",
		c.Owner, c.Repo, wf, perPage,
	)
	var resp struct {
		WorkflowRuns []WorkflowRun `json:"workflow_runs"`
	}
	if err := c.getJSON(ctx, url, &resp); err != nil {
		return nil, err
	}
	return resp.WorkflowRuns, nil
}

// TriggerWorkflow dispatches workflow_dispatch.
func (c *Client) TriggerWorkflow(ctx context.Context, ref string) error {
	if !c.Enabled() {
		return fmt.Errorf("github token not configured")
	}
	ref = strings.TrimSpace(ref)
	if ref == "" {
		ref = "main"
	}
	wf := strings.TrimSpace(c.Workflow)
	if wf == "" {
		wf = "flutter-release.yml"
	}
	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/actions/workflows/%s/dispatches",
		c.Owner, c.Repo, wf,
	)
	body, _ := json.Marshal(map[string]string{"ref": ref})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Authorization", "Bearer "+c.Token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		b, _ := io.ReadAll(res.Body)
		return fmt.Errorf("github dispatch %s: %s", res.Status, strings.TrimSpace(string(b)))
	}
	return nil
}

func (c *Client) getJSON(ctx context.Context, url string, dest any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Authorization", "Bearer "+c.Token)
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		b, _ := io.ReadAll(res.Body)
		return fmt.Errorf("github %s: %s", res.Status, strings.TrimSpace(string(b)))
	}
	return json.NewDecoder(res.Body).Decode(dest)
}
