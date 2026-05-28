package llm

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	llmbiz "backend/internal/biz/llm"
	"backend/pkg/llminference"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type ChatLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatLogic {
	return &ChatLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatLogic) Chat(req *types.LlmChatReq) (resp *types.LlmChatResp, err error) {
	deps, buildErr := platformChatDepsFromSvc(l.svcCtx)
	if buildErr != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(buildErr),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     false,
		}, nil
	}
	deps.ChatComplete = platformChatCompleter(l.ctx, l.svcCtx, deps.Inference)
	outcome, execErr := llmbiz.ExecutePlatformChat(l.ctx, deps, platformChatInputFromReq(req))
	if execErr != nil {
		return nil, execErr
	}
	return platformChatOutcomeToResp(outcome), nil
}

func platformChatCompleter(ctx context.Context, svcCtx *svc.ServiceContext, _ llminference.Config) llmbiz.ChatCompleter {
	return func(callCtx context.Context, model string, messages []llmbiz.ChatMessage, opts llmbiz.ChatOptions) (string, error) {
		if svcCtx.LLMApp != nil {
			return svcCtx.LLMApp.PostChatCompletion(callCtx, model, messages, opts)
		}
		cfg, err := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
		if err != nil {
			return "", err
		}
		commonMsgs := make([]common.ChatMessage, len(messages))
		for i, m := range messages {
			commonMsgs[i] = common.ChatMessage{Role: m.Role, Content: m.Content}
		}
		client := utils.NewHTTPClient(cfg.TimeoutSeconds)
		return common.PostChatCompletion(ctx, client, cfg, model, commonMsgs, common.ChatOptions{
			Temperature: opts.Temperature,
			TopP:        opts.TopP,
			MaxTokens:   opts.MaxTokens,
		})
	}
}
