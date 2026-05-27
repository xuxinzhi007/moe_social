// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"context"
	"io"
	"net/http"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type ModelsRawLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewModelsRawLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ModelsRawLogic {
	return &ModelsRawLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

// ModelsRaw 返回 Ollama /api/tags 的原始 JSON，不包装为 BaseResp。
func (l *ModelsRawLogic) ModelsRaw(w http.ResponseWriter, r *http.Request) error {
	timeoutSeconds := l.svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 10
	}

	baseURL, err := common.ResolveInferenceBaseURL(l.svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, baseURL+"/api/tags", nil)
	if err != nil {
		return err
	}
	common.ApplyInferenceForwardHeaders(req)

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
