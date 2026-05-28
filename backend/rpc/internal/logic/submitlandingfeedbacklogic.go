package logic

import (
	"context"
	"errors"

	landingbiz "backend/internal/biz/landing"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type SubmitLandingFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSubmitLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitLandingFeedbackLogic {
	return &SubmitLandingFeedbackLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SubmitLandingFeedbackLogic) SubmitLandingFeedback(in *moe.SubmitLandingFeedbackReq) (*moe.SubmitLandingFeedbackResp, error) {
	id, err := landingbiz.Submit(l.ctx, l.svcCtx.DB, landingbiz.SubmitInput{
		Email:     in.GetEmail(),
		Category:  in.GetCategory(),
		Content:   in.GetContent(),
		Source:    in.GetSource(),
		ClientIP:  in.GetClientIp(),
		UserAgent: in.GetUserAgent(),
	})
	if err != nil {
		switch {
		case errors.Is(err, landingbiz.ErrInvalidEmail):
			return nil, errorx.InvalidArgument("请填写有效的联系邮箱")
		case errors.Is(err, landingbiz.ErrInvalidArgument):
			return nil, errorx.InvalidArgument("反馈内容至少 5 个字")
		case errors.Is(err, landingbiz.ErrTooLong):
			return nil, errorx.InvalidArgument("反馈内容不能超过 2000 字")
		case errors.Is(err, landingbiz.ErrRateLimited):
			return nil, errorx.New(429, "提交过于频繁，请稍后再试")
		default:
			l.Errorf("[landing] create feedback: %v", err)
			return nil, errorx.Internal("服务器内部错误")
		}
	}

	email, _ := utils.NormalizeFeishuEmail(in.GetEmail())
	l.Infof("[landing] feedback saved id=%d email=%s", id, logutil.MaskEmail(email))

	return &moe.SubmitLandingFeedbackResp{Id: id}, nil
}
