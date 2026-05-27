package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapGiftsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapGiftsLogic {
	return &AdminBootstrapGiftsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapGiftsLogic) AdminBootstrapGifts(_ *types.EmptyReq) (resp *types.AdminBootstrapGiftsResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminBootstrapGifts(l.ctx, &super.AdminBootstrapGiftsReq{})
	if err != nil {
		return &types.AdminBootstrapGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	msg := "礼物表已有数据，未导入"
	if rpcResp.GetCreated() > 0 {
		msg = "已导入默认礼物"
	}
	resp = &types.AdminBootstrapGiftsResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     types.AdminBootstrapGiftsData{Created: int(rpcResp.GetCreated())},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "gift", "", "导入默认礼物")
	}
	return resp, nil
}
