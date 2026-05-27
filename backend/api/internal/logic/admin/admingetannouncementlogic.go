package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetAnnouncementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetAnnouncementLogic {
	return &AdminGetAnnouncementLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetAnnouncementLogic) AdminGetAnnouncement(req *types.AdminGetAnnouncementReq) (*types.AdminGetAnnouncementResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetAnnouncement(l.ctx, &super.AdminGetAnnouncementReq{
		AnnouncementId: req.AnnouncementId,
	})
	if err != nil {
		return &types.AdminGetAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetAnnouncementResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
	}, nil
}
