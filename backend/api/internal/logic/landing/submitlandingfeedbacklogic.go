// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package landing

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SubmitLandingFeedbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSubmitLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitLandingFeedbackLogic {
	return &SubmitLandingFeedbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SubmitLandingFeedbackLogic) SubmitLandingFeedback(
	req *types.SubmitLandingFeedbackReq,
	clientIP, userAgent string,
) (resp *types.SubmitLandingFeedbackResp, err error) {
	source := strings.TrimSpace(req.Source)
	if source == "" {
		source = "official-site"
	}

	_, err = l.svcCtx.SuperRpcClient.SubmitLandingFeedback(l.ctx, &super.SubmitLandingFeedbackReq{
		Email:     strings.TrimSpace(req.Email),
		Category:  strings.TrimSpace(req.Category),
		Content:   req.Content,
		Source:    source,
		ClientIp:  clientIP,
		UserAgent: userAgent,
	})
	if err != nil {
		return &types.SubmitLandingFeedbackResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.SubmitLandingFeedbackResp{
		BaseResp: common.HandleRPCError(nil, "感谢你的反馈，我们已收到"),
	}, nil
}
