// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package ops

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListLandingFeedbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLandingFeedbackLogic {
	return &ListLandingFeedbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListLandingFeedbackLogic) ListLandingFeedback(req *types.ListLandingFeedbackReq) (resp *types.ListLandingFeedbackResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}

	rpcResp, err := l.svcCtx.LandingGW.ListLandingFeedback(l.ctx, &super.ListLandingFeedbackReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		Category: strings.TrimSpace(req.Category),
	})
	if err != nil {
		return &types.ListLandingFeedbackResp{
			BaseResp: common.HandleLandingGWError(err, ""),
		}, nil
	}

	items := make([]types.LandingFeedbackItem, 0, len(rpcResp.Items))
	for _, it := range rpcResp.Items {
		if it == nil {
			continue
		}
		items = append(items, types.LandingFeedbackItem{
			Id:        it.Id,
			Email:     it.Email,
			Category:  it.Category,
			Content:   it.Content,
			Source:    it.Source,
			ClientIp:  it.ClientIp,
			UserAgent: it.UserAgent,
			CreatedAt: it.CreatedAt,
		})
	}

	return &types.ListLandingFeedbackResp{
		BaseResp: common.HandleLandingGWError(nil, "ok"),
		Data: types.ListLandingFeedbackData{
			Items: items,
			Total: int(rpcResp.Total),
		},
	}, nil
}
