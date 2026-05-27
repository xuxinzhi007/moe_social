package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAiAgentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAiAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiAgentsLogic {
	return &AdminListAiAgentsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAiAgentsLogic) AdminListAiAgents(in *super.AdminListAiAgentsReq) (*super.AdminListAiAgentsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListAiAgents(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("[admin] list ai agents: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
