// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"context"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type ShowRawLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewShowRawLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ShowRawLogic {
	return &ShowRawLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

// ShowRaw 代理 POST /api/show 到 Ollama，返回原始响应。
func (l *ShowRawLogic) ShowRaw(w http.ResponseWriter, r *http.Request) error {
	timeoutSeconds := l.svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 15
	}

	baseURL, err := common.ResolveInferenceBaseURL(l.svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		return err
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost,
		baseURL+"/api/show",
		strings.NewReader(string(body)),
	)
	if err != nil {
		return err
	}
	common.ApplyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(raw)
	return nil
}
