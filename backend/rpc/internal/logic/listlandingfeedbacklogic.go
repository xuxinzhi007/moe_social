package logic

import (
	"context"

	landingbiz "backend/internal/biz/landing"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListLandingFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLandingFeedbackLogic {
	return &ListLandingFeedbackLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListLandingFeedbackLogic) ListLandingFeedback(in *super.ListLandingFeedbackReq) (*super.ListLandingFeedbackResp, error) {
	result, err := landingbiz.List(l.ctx, l.svcCtx.DB, landingbiz.ListFilter{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
		Category: in.GetCategory(),
	})
	if err != nil {
		l.Errorf("[landing] list feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	return &super.ListLandingFeedbackResp{
		Items: landingbiz.FeedbackItemsToProto(result.Rows),
		Total: int32(result.Total),
	}, nil
}
