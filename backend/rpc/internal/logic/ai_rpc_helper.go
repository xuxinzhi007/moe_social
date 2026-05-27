package logic

import (
	aiapp "backend/internal/service/ai"
	"backend/rpc/internal/svc"
)

func aiApp(svcCtx *svc.ServiceContext) *aiapp.AppService {
	return aiapp.New(svcCtx.DB)
}
