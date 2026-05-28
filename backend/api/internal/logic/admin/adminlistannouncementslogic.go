package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAnnouncementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAnnouncementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAnnouncementsLogic {
	return &AdminListAnnouncementsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAnnouncementsLogic) AdminListAnnouncements(req *types.AdminListAnnouncementsReq) (*types.AdminListAnnouncementsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAnnouncements(l.ctx, &moe.AdminListAnnouncementsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
		Status:   req.Status,
	})
	if err != nil {
		return &types.AdminListAnnouncementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAnnouncementItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminAnnouncementToTypes(item)
	}
	return &types.AdminListAnnouncementsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListAnnouncementsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
