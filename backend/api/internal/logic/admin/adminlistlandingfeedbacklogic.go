// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"

	"backend/api/internal/logic/ops"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListLandingFeedbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListLandingFeedbackLogic {
	return &AdminListLandingFeedbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListLandingFeedbackLogic) AdminListLandingFeedback(req *types.ListLandingFeedbackReq) (resp *types.ListLandingFeedbackResp, err error) {
	inner := ops.NewListLandingFeedbackLogic(l.ctx, l.svcCtx)
	return inner.ListLandingFeedback(req)
}
