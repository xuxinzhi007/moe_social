package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminPublishAnnouncementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminPublishAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminPublishAnnouncementLogic {
	return &AdminPublishAnnouncementLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminPublishAnnouncementLogic) AdminPublishAnnouncement(req *types.AdminPublishAnnouncementReq) (*types.AdminPublishAnnouncementResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminPublishAnnouncement(l.ctx, &super.AdminPublishAnnouncementReq{
		AnnouncementId: req.AnnouncementId,
	})
	if err != nil {
		return &types.AdminPublishAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminPublishAnnouncementResp{
		BaseResp: common.HandleRPCError(nil, "发布成功"),
		Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "publish", "announcement", req.AnnouncementId, "发布公告")
	}
	return resp, nil
}
