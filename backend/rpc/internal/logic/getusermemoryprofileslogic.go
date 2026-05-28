package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoryProfilesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserMemoryProfilesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoryProfilesLogic {
	return &GetUserMemoryProfilesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserMemoryProfilesLogic) GetUserMemoryProfiles(in *moe.GetUserMemoryProfilesReq) (*moe.GetUserMemoryProfilesResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).GetUserMemoryProfiles(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
