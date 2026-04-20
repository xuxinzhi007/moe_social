package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type DownloadModelLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDownloadModelLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DownloadModelLogic {
	return &DownloadModelLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DownloadModelLogic) DownloadModel(req *types.LlmDownloadModelReq) (resp *types.BaseResp, err error) {
	if req.Model == "" {
		resp := common.HandleError(fmt.Errorf("模型名称不能为空"))
		return &resp, nil
	}

	timeoutSeconds := l.svcCtx.Config.Ollama.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 300 // 下载模型需要更长时间
	}

	baseUrl := strings.TrimRight(l.svcCtx.Config.Ollama.BaseUrl, "/")
	if baseUrl == "" {
		baseUrl = "http://127.0.0.1:11434"
	}

	client := utils.NewHTTPClient(timeoutSeconds)

	body, err := json.Marshal(map[string]string{
		"name": req.Model,
	})
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, baseUrl+"/api/pull", bytes.NewReader(body))
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	httpReq.Header.Set("Content-Type", "application/json")

	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && (httpResp.StatusCode == http.StatusOK || httpResp.StatusCode == http.StatusAccepted) {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		resp := common.HandleError(retryErr)
		return &resp, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK && httpResp.StatusCode != http.StatusAccepted {
		raw, _ := io.ReadAll(httpResp.Body)
		resp := common.HandleError(fmt.Errorf("下载模型失败: %d %s", httpResp.StatusCode, string(raw)))
		return &resp, nil
	}

	// 处理流式响应
	reader := httpResp.Body
	decoder := json.NewDecoder(reader)

	for {
		var chunk map[string]interface{}
		if err := decoder.Decode(&chunk); err != nil {
			if err == io.EOF {
				break
			}
			l.Errorf("decode download chunk failed: %v", err)
			continue
		}

		// 可以在这里处理下载进度，例如发送WebSocket通知
		if status, ok := chunk["status"].(string); ok {
			l.Infof("Download status: %s", status)
		}
		if progress, ok := chunk["progress"].(float64); ok {
			l.Infof("Download progress: %.2f%%", progress*100)
		}
	}

	// 清空模型缓存，确保下次获取最新列表
	l.svcCtx.ModelCache.Clear()

	respValue := common.HandleError(nil)
	respValue.Message = "模型下载成功"
	return &respValue, nil
}
