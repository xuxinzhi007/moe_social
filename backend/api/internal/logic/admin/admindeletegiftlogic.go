package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteGiftLogic {
	return &AdminDeleteGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteGiftLogic) AdminDeleteGift(req *types.AdminDeleteGiftReq) (resp *types.AdminDeleteGiftResp, err error) {
	_, err = l.svcCtx.AdminGW.AdminDeleteGift(l.ctx, &super.AdminDeleteGiftReq{
		GiftId: req.GiftId,
	})
	if err != nil {
		return &types.AdminDeleteGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp = &types.AdminDeleteGiftResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "gift", req.GiftId, "删除礼物")
	}
	return resp, nil
}
