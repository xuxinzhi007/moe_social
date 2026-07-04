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
	// 小模型 narrator：只走一次流式 prose，不尝试 JSON（0.5B 写 JSON 必崩）。
	if IsNarratorMode(deps) {
		out, err := callTurnLLMProseStream(ctx, deps, ctxPrompt, onChunk)
		if err != nil {
			moelog.Infof("game narrator stream failed: %v", err)
			out = fallbackTurn(action, intent, scene, npcViews, flags)
			return normalizeTurnOutput(out, flags, scene.Name), "fallback", nil
		}
		out = normalizeTurnOutput(out, flags, scene.Name)
		out.Prose = sanitizeNarratorProse(out.Prose)
		if !isValidProse(out.Prose) {
			out = fallbackTurn(action, intent, scene, npcViews, flags)
			return out, "fallback", nil
		}
		return out, "llm_prose", nil
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
	narrator := IsNarratorMode(deps)
	maxTokens := 320
	if narrator {
		maxTokens = 200
	}
	content, err := llminference.ChatStream(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "只输出一段中文小说正文，不要标题，不要 JSON，不要分节。"},
		{Role: "user", Content: prosePromptForDeps(deps, ctxPrompt)},
	}, llminference.ChatOptions{Temperature: 0.75, MaxTokens: maxTokens}, func(chunk string) error {
		// 小模型流式常复读设定文档；narrator 只推送清洗后终稿，避免客户端刷屏。
		if narrator || onChunk == nil {
			return nil
		}
		return onChunk(chunk)
	})
	if err != nil {
		return turnLLMOutput{}, err
	}
	out, ok := parseTurnLLMContent(content)
	if !ok {
		out = turnLLMOutput{Prose: sanitizeNarratorProse(content)}
	} else {
		out.Prose = sanitizeNarratorProse(out.Prose)
	}
	if narrator && onChunk != nil && strings.TrimSpace(out.Prose) != "" {
		_ = onChunk(out.Prose)
	}
	return out, nil
}

func prosePromptForDeps(deps TurnDeps, ctx actPromptContext) string {
	if IsNarratorMode(deps) {
		return buildNarratorPromptProse(ctx)
	}
	return buildActPromptProse(ctx)
}
