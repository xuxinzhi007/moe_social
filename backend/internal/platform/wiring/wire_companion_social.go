package runserver

import (
	"context"

	"backend/internal/platform/svc"
)

// wireCompanionSocialEvents adds an optional projection from existing social
// writes into CompanionEvent without changing the social domain contracts.
func wireCompanionSocialEvents(ctx *svc.ServiceContext) {
	if ctx == nil || ctx.CompanionApp == nil {
		return
	}
	recorder := func(
		requestContext context.Context,
		userID uint,
		eventType string,
		sourceID uint,
		payload map[string]interface{},
	) error {
		return ctx.CompanionApp.RecordSocialEvent(
			requestContext, userID, eventType, sourceID, payload,
		)
	}
	if ctx.PostApp != nil {
		ctx.PostApp.SetCompanionEventRecorder(recorder)
	}
	if ctx.CommentApp != nil {
		ctx.CommentApp.SetCompanionEventRecorder(recorder)
	}
	if ctx.UserApp != nil {
		ctx.UserApp.SetCompanionEventRecorder(recorder)
	}
}
