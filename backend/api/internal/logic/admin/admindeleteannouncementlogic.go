package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAnnouncementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAnnouncementLogic {
	return &AdminDeleteAnnouncementLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteAnnouncementLogic) AdminDeleteAnnouncement(req *types.AdminDeleteAnnouncementReq) (*types.AdminDeleteAnnouncementResp, error) {
	_, err := l.svcCtx.AdminGW.AdminDeleteAnnouncement(l.ctx, &super.AdminDeleteAnnouncementReq{
		AnnouncementId: req.AnnouncementId,
	})
	if err != nil {
		return &types.AdminDeleteAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteAnnouncementResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "announcement", req.AnnouncementId, "删除公告")
	}
	return resp, nil
}
