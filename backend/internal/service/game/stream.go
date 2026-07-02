package gameapp

import (
	"context"

	gamebiz "backend/internal/biz/game"
)

// RunActStream 流式执行游戏回合（P3 SSE）。
func (s *AppService) RunActStream(
	ctx context.Context,
	userID string,
	sessionID uint64,
	action string,
	onChunk gamebiz.ProseStreamHandler,
) (gamebiz.ActResult, error) {
	if s == nil || s.store == nil {
		return gamebiz.ActResult{}, errGameUnavailable()
	}
	return gamebiz.RunActStreamTurn(ctx, s.store, s.turnDeps(), userID, sessionID, action, onChunk)
}

func errGameUnavailable() error {
	return gamebizErr("game service unavailable")
}

type gamebizErr string

func (e gamebizErr) Error() string { return string(e) }
