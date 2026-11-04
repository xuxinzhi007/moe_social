package moewiring

import (
	"context"

	replyassistbiz "backend/internal/biz/replyassist"
	companionapp "backend/internal/service/companion"
	replyassistapp "backend/internal/service/replyassist"
	"backend/pkg/conf"
	"backend/pkg/llminference"
)

// NewAPIReplyAssistService wires reply-assist when companion domain is in-process.
func NewAPIReplyAssistService(companion *companionapp.AppService) *replyassistapp.AppService {
	if !CompanionAPIInProcessEnabled() {
		return nil
	}
	inf := conf.Inference()
	model := llminference.ResolveModelName(context.Background(), inf, inf.DefaultModel)
	engine := replyassistbiz.NewEngine(inf, model)
	svc := replyassistapp.New(engine)
	if companion != nil {
		svc.UseInferenceResolver(func(ctx context.Context, userID uint) (*llminference.Config, error) {
			return companion.ResolveChatInference(ctx, userID)
		})
	}
	return svc
}
