package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateAnnouncementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAnnouncementLogic {
	return &AdminCreateAnnouncementLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminCreateAnnouncementLogic) AdminCreateAnnouncement(req *types.AdminCreateAnnouncementReq) (*types.AdminCreateAnnouncementResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminCreateAnnouncement(l.ctx, &super.AdminCreateAnnouncementReq{
		Title:   req.Title,
		Content: req.Content,
	})
	if err != nil {
		return &types.AdminCreateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminCreateAnnouncementResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "announcement", resp.Data.Id, "创建公告")
	}
	return resp, nil
}
