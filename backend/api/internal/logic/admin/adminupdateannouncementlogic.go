package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAnnouncementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAnnouncementLogic {
	return &AdminUpdateAnnouncementLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateAnnouncementLogic) AdminUpdateAnnouncement(req *types.AdminUpdateAnnouncementReq) (*types.AdminUpdateAnnouncementResp, error) {
	rpcReq := &super.AdminUpdateAnnouncementReq{AnnouncementId: req.AnnouncementId}
	if title := strings.TrimSpace(req.Title); title != "" {
		rpcReq.Title = title
		rpcReq.UpdateTitle = true
	}
	if req.Content != "" {
		rpcReq.Content = req.Content
		rpcReq.UpdateContent = true
	}
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateAnnouncement(l.ctx, rpcReq)
	if err != nil {
		return &types.AdminUpdateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpdateAnnouncementResp{
		BaseResp: common.HandleRPCError(nil, "更新成功"),
		Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "announcement", req.AnnouncementId, "更新公告")
	}
	return resp, nil
}
