// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"context"
	"io"
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type ChatRawLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatRawLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatRawLogic {
	return &ChatRawLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

// ChatRaw 将请求体原样转发到 Ollama /api/chat，流式响应时逐块写出。
func (l *ChatRawLogic) ChatRaw(w http.ResponseWriter, r *http.Request) error {
	baseURL, err := common.ResolveOllamaBaseURL(l.svcCtx.Config.Ollama.BaseUrl)
	if err != nil {
		return err
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: 0}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost, baseURL+"/api/chat", strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	common.ApplyOllamaForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	} else {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
	}
	w.WriteHeader(resp.StatusCode)

	flusher, _ := w.(http.Flusher)
	buf := make([]byte, 16*1024)
	for {
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return nil
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return readErr
		}
	}
	return nil
}
