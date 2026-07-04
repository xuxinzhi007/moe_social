package gamebiz

import (
	"context"
	"time"
)

const (
	turnContextTimeout  = 3 * time.Minute
	commitContextTimeout = 20 * time.Second
)

// turnContext 整回合 ctx：与 HTTP 断开解耦，避免 LLM 流式结束后 persist 被取消。
func turnContext(ctx context.Context) (context.Context, context.CancelFunc) {
	base := context.WithoutCancel(ctx)
	return context.WithTimeout(base, turnContextTimeout)
}

// commitContext 落库专用 ctx：请求已结束也保证 turn_log / session 写入成功。
func commitContext(ctx context.Context) (context.Context, context.CancelFunc) {
	base := context.WithoutCancel(ctx)
	return context.WithTimeout(base, commitContextTimeout)
}
