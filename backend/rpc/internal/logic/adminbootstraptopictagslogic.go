package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapTopicTagsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapTopicTagsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapTopicTagsLogic {
	return &AdminBootstrapTopicTagsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapTopicTagsLogic) AdminBootstrapTopicTags(in *moe.AdminBootstrapTopicTagsReq) (*moe.AdminBootstrapTopicTagsResp, error) {
	_ = in
	return adminapp.New(l.svcCtx.DB).AdminBootstrapTopicTags(l.ctx, in)
}
