package adminapphttp

import (
	"context"

	"backend/internal/apilegacy/common"
	"backend/internal/platform/svc"
	aiapp "backend/internal/service/ai"
)

type RuntimeState struct {
	ClientPublicAPIBaseURL string
	ImagePublicBaseURL     string
	ImageLocalDir          string
	ImageMaxBytes          int64
}

type Deps struct {
	AIApp       *aiapp.AppService
	Runtime     *RuntimeState
	RecordAudit func(ctx context.Context, action, resource, resourceID, detail string)
}

type Option func(*Server)

func WithDeps(deps Deps) Option {
	return func(s *Server) {
		s.ai = deps.AIApp
		s.runtime = deps.Runtime
		s.recordAudit = deps.RecordAudit
	}
}

func WithAIApp(app *aiapp.AppService) Option {
	return func(s *Server) {
		s.ai = app
	}
}

func DepsFromServiceContext(svcCtx *svc.ServiceContext) Deps {
	if svcCtx == nil {
		return Deps{}
	}
	runtime := &RuntimeState{
		ClientPublicAPIBaseURL: svcCtx.Config.ClientPublicApiBaseUrl,
		ImagePublicBaseURL:     svcCtx.Config.Image.PublicBaseUrl,
		ImageLocalDir:          svcCtx.Config.Image.LocalDir,
		ImageMaxBytes:          svcCtx.Config.Image.MaxBytes,
	}
	return Deps{
		AIApp:   svcCtx.Domains.AI.AIApp,
		Runtime: runtime,
		RecordAudit: func(ctx context.Context, action, resource, resourceID, detail string) {
			common.TryRecordAdminAudit(ctx, svcCtx, action, resource, resourceID, detail)
		},
	}
}