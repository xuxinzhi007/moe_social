package admin

import (
	"context"

	moebiz "backend/internal/biz/moe"
	moeadmin "backend/internal/service/moe"
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMoeToolCallsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMoeToolCallsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMoeToolCallsLogic {
	return &AdminListMoeToolCallsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListMoeToolCallsLogic) AdminListMoeToolCalls(req *types.AdminListMoeToolCallsReq) (*types.AdminListMoeToolCallsResp, error) {
	rows, total, err := l.svcCtx.MoeGW.ListToolCalls(l.ctx, moebiz.ToolCallsFilter{
		From:        moeadmin.ParseTimeFilter(req.From, false),
		To:          moeadmin.ParseTimeFilter(req.To, true),
		AgentKey:    req.AgentKey,
		Tool:        req.Tool,
		Source:      req.Source,
		ActorUserID: moebiz.ParseActorUserID(req.ActorUserId),
		OkOnly:      req.OkOnly,
		FailedOnly:  req.FailedOnly,
		Page:        req.Page,
		PageSize:    req.PageSize,
	})
	if err != nil {
		return &types.AdminListMoeToolCallsResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminListMoeToolCallsResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.ToolCallsDataFromBiz(rows, total),
	}, nil
}
