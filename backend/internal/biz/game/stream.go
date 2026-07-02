package gamebiz

import (
	"context"
	"strings"

	"backend/internal/platform/moelog"
	"backend/model"
	"backend/pkg/llminference"
)

// ProseStreamHandler 叙事流式增量回调（P3 SSE）。
type ProseStreamHandler func(chunk string) error

// ActStream 兼容入口；流式由 RunActStreamTurn → RunTurn 完成。
func ActStream(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	userIDRaw string,
	sessionID uint64,
	action string,
	onChunk ProseStreamHandler,
) (ActResult, error) {
	return RunActStreamTurn(ctx, st, deps, userIDRaw, sessionID, action, onChunk)
}

// RunActStreamTurn SSE 流式回合（与 Act 共用 RunTurn 流水线）。
func RunActStreamTurn(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	userIDRaw string,
	sessionID uint64,
	action string,
	onChunk ProseStreamHandler,
) (ActResult, error) {
	return RunTurn(ctx, st, deps, userIDRaw, sessionID, action, onChunk)
}

func resolveTurnOutputStream(
	ctx context.Context,
	deps TurnDeps,
	ctxPrompt actPromptContext,
	action string,
	scene model.GameScene,
	npcViews []NpcView,
	flags WorldFlags,
	intent PlayerIntent,
	onChunk ProseStreamHandler,
) (turnLLMOutput, string, error) {
	if !deps.Inference.Ready() {
		return fallbackTurn(action, intent, scene, npcViews, flags), "fallback", nil
	}
	candidates := turnModelCandidates(ctx, deps)
	var lastErr error
	for _, modelName := range candidates {
		tryDeps := deps
		tryDeps.Model = modelName

		if out, err := callTurnLLMJSON(ctx, tryDeps, ctxPrompt); err == nil {
			out = normalizeTurnOutput(out, flags, scene.Name)
			if isValidProse(out.Prose) {
				if onChunk != nil {
					_ = onChunk(out.Prose)
				}
				return out, "llm_json", nil
			}
		} else {
			lastErr = err
		}

		if out, err := callTurnLLMProseStream(ctx, tryDeps, ctxPrompt, onChunk); err == nil {
			out = normalizeTurnOutput(out, flags, scene.Name)
			if isValidProse(out.Prose) {
				return out, "llm_prose", nil
			}
		} else {
			lastErr = err
		}
	}
	if lastErr != nil {
		moelog.Infof("game stream fallback: llm failed action=%q err=%v", action, lastErr)
	}
	out := fallbackTurn(action, intent, scene, npcViews, flags)
	if onChunk != nil && strings.TrimSpace(out.Prose) != "" {
		_ = onChunk(out.Prose)
	}
	return out, "fallback", nil
}

func callTurnLLMProseStream(
	ctx context.Context,
	deps TurnDeps,
	ctxPrompt actPromptContext,
	onChunk ProseStreamHandler,
) (turnLLMOutput, error) {
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = strings.TrimSpace(deps.Inference.DefaultModel)
	}
	content, err := llminference.ChatStream(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "你是文字冒险叙事引擎。只输出一段中文小说正文，禁止 JSON。"},
		{Role: "user", Content: buildActPromptProse(ctxPrompt)},
	}, llminference.ChatOptions{Temperature: 0.9, MaxTokens: 900}, func(chunk string) error {
		if onChunk == nil {
			return nil
		}
		return onChunk(chunk)
	})
	if err != nil {
		return turnLLMOutput{}, err
	}
	out, ok := parseTurnLLMContent(content)
	if !ok {
		return turnLLMOutput{Prose: content}, nil
	}
	return out, nil
}
